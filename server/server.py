from omegaconf import OmegaConf
import torch
import os
from os import path
import sys

sys.path.append(path.dirname(path.dirname(path.abspath(__file__))))
from .strategy.strategy import Strategy
from .strategy.fedavg import FedAvg
from .calculate import get_latest_folder, get_clients_uploads_after, calculate_client_scores
from utils.chain_record import send_score
from datetime import datetime, timedelta
import socket
import pickle
import logging
import grpc
from concurrent import futures
from utils.proto_py import communicate_pb2_grpc
from .grpc_servicer import WeightsTransferServicer
import json
import time

_ONE_DAY_IN_SECONDS = 60 * 60 * 24


class BaseServer:
    def __init__(self, cfg_path: str, strategy: Strategy = None):
        self.config_detail = OmegaConf.load(cfg_path)
        self.cfg_path = cfg_path
        self.model_parameter = None
        self.num_clients = self.config_detail.num_clients
        self.host = self.config_detail.server.host
        self.port = self.config_detail.server.port
        self.save_path = "./save"
        self.output = './server_output'
        self.strategy = strategy if strategy is not None else FedAvg()
        self.latest_version = get_latest_folder(self.config_detail.sft.training_arguments.output_dir)
        if self.latest_version is None:
            output_path = os.path.join(
                self.config_detail.sft.training_arguments.output_dir,
                (datetime.today() - timedelta(days=1)).strftime("%Y%m%d_%H%M%S")
            )
            os.makedirs(output_path, exist_ok=True)
            self.latest_version = output_path
        self.use_chain = self.config_detail.chain_record

    def aggregate(self, client_list, dataset_len_list, weight_path_list):
        self.model_parameter = self.strategy.aggregate(client_list,
                                                       dataset_len_list,
                                                       weight_path_list)

    def save_model(self):
        new_version = datetime.today().strftime("%Y%m%d_%H%M%S")
        save_path = os.path.join(
                self.output,
                new_version)
        os.makedirs(save_path, exist_ok=True)
        torch.save(
            self.model_parameter,
            os.path.join(
                save_path,
                "adapter_model.bin",
            ),
        )
        self.latest_version = new_version
        logging.info(f'New model weight saved in :{save_path}')

    def eval(self):  # TODO add evaluation
        pass

    def update(self, do_eval=False):
        """Aggregate model and save new model weight, send reward to each client"""
        clients_detail, dataset_length_list, path_list = get_clients_uploads_after(self.save_path, self.latest_version)
        client_list = clients_detail.keys()
        if len(client_list) > 0:
            self.aggregate(clients_detail.keys(), dataset_length_list, path_list)
            self.save_model()
            # send score to each client address
            if self.use_chain is True:
                score_percentage = calculate_client_scores(clients_detail)
                for user_address, score in score_percentage.items():
                    send_score(user_address, score)
        else:
            logging.info('No new weights from client')

    def start(self):
        current_date = datetime.today().strftime("%Y%m%d_%H%M%S")
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind((self.host, self.port))
            s.listen()
            print(f"Server listening on {self.host}:{self.port}")

            client_weights = {}
            client_list = []
            for _ in range(self.num_clients):
                conn, addr = s.accept()
                with conn:
                    print(f"Connected by {addr}")
                    # Send current model weights
                    # data = pickle.dumps(self.model.state_dict())
                    # conn.sendall(data)

                    # Receive updated weights
                    data = b""
                    while True:
                        packet = conn.recv(4096)
                        if not packet:
                            break
                        data += packet
                    recv_data = pickle.loads(data)
                    print(
                        f'Received data from client: {recv_data["client_id"]}, data: {recv_data}'
                    )
                    client_list.append(recv_data["client_id"])
                    client_weights[recv_data["client_id"]] = recv_data[
                        "new_model_weight"
                    ]

                    client_save_path = os.path.join(
                        self.save_path,
                        "local_output_{}".format(str(recv_data["client_id"])),
                        current_date.split('_')[0],
                        current_date.split('_')[1],
                    )
                    os.makedirs(client_save_path, exist_ok=True)
                    torch.save(
                        recv_data["new_model_weight"],
                        client_save_path + "/pytorch_model.bin",
                    )
                    with open(client_save_path + 'train_dataset_length.json', 'w') as f:
                        json.dump({"train_dataset_length": recv_data['train_dataset_length']}, f)

            # Average the weights
            # self.aggregate(client_list, client_weights)
            # print("Federated learning complete")
            # self.save_model()

    def run_grpc_server(self):
        grpc_server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
        communicate_pb2_grpc.add_WeightsTransferServicer_to_server(WeightsTransferServicer(self), grpc_server)
        grpc_server.add_insecure_port('[::]:50051')
        grpc_server.start()
        print("Server started, listening on port 50051.")
        try:
            while True:  # since server.start() will not block, a sleep-loop is added to keep alive
                time.sleep(_ONE_DAY_IN_SECONDS)
        except KeyboardInterrupt:
            grpc_server.stop(0)


if __name__ == "__main__":
    server = BaseServer(cfg_path="../config.yaml")
    server.start()
