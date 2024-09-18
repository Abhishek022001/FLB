import warnings

warnings.simplefilter("ignore", UserWarning)
import os
from os import path
import sys

sys.path.append(path.dirname(path.dirname(path.abspath(__file__))))

from .baseclient import BaseClient
from trl import SFTTrainer, SFTConfig
from peft import (
    set_peft_model_state_dict,
    get_peft_model_state_dict,
    PeftModel,
    LoraConfig,
)
from collections import OrderedDict
from utils.process_data import process_dataset_for_unified_format, get_dataset
from utils.model import get_model_and_tokenizer
from utils.differential_privacy import clip_l2_norm, local_add_gaussian_noise
from utils.chain_record import send_weight
from utils.calculate import get_latest_folder
import math
import copy
import torch
import socket
import pickle
import numpy as np
import json
import requests
from datetime import datetime


def cosine_lr(
    current_round: int,
    total_round: int,
    learning_rate_max: float = 0.001,
    learning_rate_min: float = 0.0,
) -> float:
    """Implement cosine learning rate."""
    cos_inner = math.pi * current_round / total_round
    return learning_rate_min + 0.5 * (learning_rate_max - learning_rate_min) * (
        1 + math.cos(cos_inner)
    )


class Client(BaseClient):
    def __init__(self, client_id, cfg_path):
        super().__init__(client_id, cfg_path)
        self.model = None
        self.tokenizer = None
        self.sftconfig = SFTConfig(
            **self.config_detail.sft.training_arguments,
            use_cpu=True if self.config_detail.model.device_map == "cpu" else False,
            max_seq_length=self.config_detail.sft.max_seq_length,
            dataset_text_field="text",
        )

        self.train_dataset = None
        self.test_dataset = None
        self.host = self.config_detail.client.host
        self.port = self.config_detail.client.port
        self.use_chain = self.config_detail.chain_record
        self.ldp = self.config_detail.client.local_dp
        os.makedirs(self.config_detail.client.weight_file_download_path, exist_ok=True)
        self.model_weights_download_path = (
            self.config_detail.client.weight_file_download_path
        )

    def prepare_dataset(self):
        train_full = get_dataset(self.config_detail.dataset_name)
        train_test = train_full.train_test_split(test_size=0.1, seed=1122)
        train_dataset = train_test["train"]
        test_dataset = train_test["test"]
        self.train_dataset = process_dataset_for_unified_format(
            self.config_detail.dataset_name, train_dataset, self.tokenizer, seed=1122
        )
        self.test_dataset = process_dataset_for_unified_format(
            self.config_detail.dataset_name, test_dataset, self.tokenizer, seed=1122
        )

    def init_local_model(self):
        self.model, self.tokenizer = get_model_and_tokenizer(self.cfg_path)
        self.model.print_trainable_parameters()
        self.model.config.use_cache = (
            False  # silence the warnings. Please re-enable for inference!
        )
        if self.config_detail.sft.training_arguments.gradient_checkpointing:
            self.model.enable_input_require_grads()

    def initiate_local_training(self):
        self.model.config.use_cache = False
        self.params_dict_old = copy.deepcopy(
            OrderedDict(
                (name, param.detach())
                for name, param in self.model.named_parameters()
                if "default" in name
            )
        )
        self.params_dict_new = OrderedDict(
            (name, param.detach())
            for name, param in self.model.named_parameters()
            if "default" in name
        )
        self.model.state_dict = (
            lambda instance, *_, **__: get_peft_model_state_dict(
                instance, self.params_dict_new, "default"
            )
        ).__get__(self.model, type(self.model))

    def local_trainer_set(self):

        self.trainer = SFTTrainer(
            model=self.model,
            tokenizer=self.tokenizer,
            args=self.sftconfig,
            train_dataset=self.train_dataset,
            eval_dataset=self.test_dataset,
        )

    def train(self):
        results = self.trainer.train()
        return results.training_loss

    def update(self):
        if self.config_detail.client.auto_pull is True:
            try:
                url = f"{self.config_detail.server.restful_url}/latest_weight"
                response = requests.get(url, stream=True)
                response.raise_for_status()
                content_disposition = response.headers.get("Content-Disposition", "")
                filename = content_disposition.split("filename=")[-1]
                model_version = filename.split("-")[0]
                save_path = os.path.join(
                    self.model_weights_download_path, model_version
                )
                os.makedirs(save_path, exist_ok=True)
                with open(save_path + "/adapter_model.bin", "wb") as file:
                    for chunk in response.iter_content(chunk_size=8192):
                        file.write(chunk)
                print(f"Saved in {save_path}")
            except requests.RequestException as e:
                print(
                    f"Download weight file failed, please download manually. Error: {e}"
                )
                raise requests.RequestException(
                    f"Download weight file failed, please download manually. Error: {e}"
                )

        lora_config_path = os.path.join(
            self.config_detail.sft.training_arguments.output_dir, "adapter_config.json"
        )
        _, lora_weights_path_list = get_latest_folder(self.model_weights_download_path)
        if os.path.isfile(lora_config_path) and lora_weights_path_list:
            lora_weights_path = os.path.join(
                lora_weights_path_list[0], "adapter_model.bin"
            )
            config = LoraConfig.from_pretrained(
                self.config_detail.sft.training_arguments.output_dir
            )
            lora_weights = torch.load(lora_weights_path)
            model = PeftModel(self.model, config)
            set_peft_model_state_dict(model, lora_weights)
            self.model = model
        else:
            print("No Lora config and weights found. Skipping update.")

    def save(self):
        new_adapter_weight = self.model.state_dict()
        single_output_dir = os.path.join(
            self.sftconfig.output_dir,
            "local_output_{}".format(self.client_id),
        )
        os.makedirs(single_output_dir, exist_ok=True)
        torch.save(new_adapter_weight, single_output_dir + "/pytorch_model.bin")

        older_adapter_weight = get_peft_model_state_dict(
            self.model, self.params_dict_old, "default"
        )
        set_peft_model_state_dict(self.model, older_adapter_weight, "default")

        return len(self.train_dataset), new_adapter_weight

    def start(self):
        self.init_local_model()

        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((self.host, self.port))
            print(f"Connected to {self.host}:{self.port}")

            self.prepare_dataset()
            self.initiate_local_training()
            self.local_trainer_set()
            self.train()
            # No need to save the current training weights on the client.
            ## train_dataset_len, new_model_weight = self.save()
            # Only returns the weight file and related configuration information, without affecting the current client model weight.
            train_dataset_len, new_model_weight = (
                len(self.train_dataset),
                self.model.state_dict(),
            )
            lora_config_path = self.config_detail.sft.training_arguments.output_dir
            with open(lora_config_path + "/adapter_config.json", "r") as f:
                lora_config = json.load(f)

            if self.ldp is True:
                # Clipping
                new_model_weight, _ = clip_l2_norm(
                    new_model_weight,
                    self.params_dict_old,
                    self.config_detail.sft.clip_threshold,
                    self.config_detail.model.device_map,
                )
                # Add gaussian noise
                if self.config_detail.sft.dp_fedavg_gaussian_enabled is True:
                    std_dev = (
                        self.config_detail.sft.sensitivity
                        * np.sqrt(2 * np.log(1.25 / self.config_detail.sft.delta))
                        / self.config_detail.sft.epsilon
                    )
                    new_model_weight = local_add_gaussian_noise(
                        new_model_weight, std_dev, self.config_detail.model.device_map
                    )

            # Send updated weights
            data = pickle.dumps(
                {
                    "client_id": self.client_id,
                    "train_dataset_length": train_dataset_len,
                    "new_model_weight": new_model_weight,
                    "lora_config": lora_config,
                }
            )
            s.sendall(data)

        print("Training complete, weights sent to server")
        if self.use_chain is True:
            # record weight to chain, now just record file path
            current_date = datetime.today().strftime("%Y%m%d_%H%M%S")
            weight_path = os.path.join(
                self.config_detail.server.clients_file_save_path,
                "local_output_{}".format(str(self.client_id)),
                current_date,
            )
            send_weight(weight_path)

    def run_grpc_client(self):
        from .grpc_clients.grpc_client import grpc_connection
        from .grpc_clients.message import (
            SEND_PARAMETERS,
            ClientSideMessage,
            ClientSideMetadata,
        )

        server_address = f"{self.config_detail.server.host}:50051"
        insecure = self.config_detail.client.grpc_insecure
        auth_cer = (
            self.config_detail.client.grpc_auth_cer_path
            if self.config_detail.client.grpc_auth_cer_path is not None
            else None
        )
        self.init_local_model()
        self.prepare_dataset()
        self.initiate_local_training()
        self.local_trainer_set()
        self.train()

        train_dataset_len, new_model_weight = (
            len(self.train_dataset),
            self.model.state_dict(),
        )
        lora_config_path = self.config_detail.sft.training_arguments.output_dir
        with open(lora_config_path + "/adapter_config.json", "r") as f:
            lora_config = json.load(f)
        if self.ldp is True:
            # Clipping
            new_model_weight, _ = clip_l2_norm(
                new_model_weight,
                self.params_dict_old,
                self.config_detail.sft.clip_threshold,
                self.config_detail.model.device_map,
            )
            # Add gaussian noise
            if self.config_detail.sft.dp_fedavg_gaussian_enabled is True:
                std_dev = (
                    self.config_detail.sft.sensitivity
                    * np.sqrt(2 * np.log(1.25 / self.config_detail.sft.delta))
                    / self.config_detail.sft.epsilon
                )
                new_model_weight = local_add_gaussian_noise(
                    new_model_weight, std_dev, self.config_detail.model.device_map
                )
        msg_content = {
            "client_id": self.client_id,
            "train_dataset_length": train_dataset_len,
            "new_model_weight": new_model_weight,
            "lora_config": lora_config,
        }
        msg_data = ClientSideMessage(msg_content, ClientSideMetadata(SEND_PARAMETERS))

        with grpc_connection(server_address, insecure, auth_cer) as (receive, send):
            response = send(msg_data)
            print(f"Server response: {response.code}, {response.message}")

        if self.use_chain is True:
            # record weight to chain, now just record file path
            current_date = datetime.today().strftime("%Y%m%d_%H%M%S")
            weight_path = os.path.join(
                self.config_detail.server.clients_file_save_path,
                "local_output_{}".format(str(self.client_id)),
                current_date,
            )
            send_weight(weight_path)


if __name__ == "__main__":
    client = Client(client_id="1233", cfg_path="../config.yaml")
    client.run_grpc_client()
