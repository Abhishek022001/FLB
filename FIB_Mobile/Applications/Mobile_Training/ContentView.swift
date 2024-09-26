// Copyright © 2024 Apple Inc.

import LLM
import MLX
import MLXNN
import MLXOptimizers
import MLXRandom
import SwiftUI
import Tokenizers

struct ContentView: View {

    @State var evaluator = LoRAEvaluator()

    @State var prompt = """
        Hello, nice to meet you.
        """

    var body: some View {
        VStack {
            HStack {
                if let progress = evaluator.progress {
                    if let current = progress.current, let limit = progress.limit {
                        ProgressView(progress.title, value: current, total: limit)
                    } else {
                        ProgressView(progress.title)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 25)

            VStack {
                ScrollView(.vertical) {
                    ScrollViewReader { sp in
                        Group {
                            Text(evaluator.output)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity)
                        }
                        .onChange(of: evaluator.output) { _, _ in
                            sp.scrollTo("bottom")
                        }
                        .padding()

                        Spacer()
                            .frame(width: 1, height: 1)
                            .id("bottom")
                    }
                }
                VStack {
                    if evaluator.isUploadFinished {
                        Text("block number:\(evaluator.cidResponse.blockNumber)")
                        Text("transationHash:\(evaluator.cidResponse.transactionHash)")
                    }
                }
                // controls for each of the different states
                VStack {
                    switch evaluator.state {
                    case .idle:
                        Button("Start", action: start)

                    case .training:
                        EmptyView()

                    case .evaluate:
                        if evaluator.isUploadFinished {
                            Group {
                                TextEditor(text: $prompt)
                                    .frame(minHeight: 60)
                                Button("Evaluate", action: evaluate)
                            }
                            .disabled(evaluator.progress != nil)
                        }
                    case .failed(let message):
                        Text("Failed: \(message)")
                            .bold()
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }

    func start() {
        Task {
            await evaluator.start()
        }
    }

    func evaluate() {
        Task {
            await evaluator.evaluate(prompt: prompt)
        }
    }
}

/// Progress reporting with a title.
struct Progress: Equatable, Sendable {
    let title: String
    let current: Double?
    let limit: Double?
}

@Observable
class LoRAEvaluator {

    enum State: Sendable {
        case idle
        case training
        case evaluate
        case failed(String)
    }

    enum ModelState: Sendable {
        case idle
        case loaded(ModelContainer)
    }

    var state = State.idle
    var progress: Progress?

    var output = ""
    
    var cidResponse: CIDReponse = CIDReponse(blockNumber: 0, transactionHash: "")

    var isUploadFinished = false

    /*  support model list
                llama3_1_8B_4bit,
                mistralNeMo4bit,
                smolLM_135M_4bit,
                mistral7B4bit,
                codeLlama13b4bit,
                phi4bit,
                phi3_5_4bit,
                gemma2bQuantized,
                gemma_2_9b_it_4bit,
                qwen205b4bit,
                openelm270m4bit,
    */
    private let modelConfiguration = ModelConfiguration.phi3_5_4bit
    private var model: ModelState = .idle

    private let loraLayers = 4
    private let learningRate: Float = 1e-5

    // Training Steps
    private let parameters = LoRATrain.Parameters(batchSize: 1, iterations: 60)

    private let generateParameters = GenerateParameters(temperature: 0.6, topP: 0.9)
    private let evaluateShowEvery = 8
    private let maxTokens = 200

    private func loadModel() async throws -> ModelContainer {
        switch self.model {
        case .idle:
            let name = modelConfiguration.name
            await MainActor.run {
                progress = .init(title: "Loading \(name)", current: 0, limit: 1)
            }

            let modelContainer = try await LLM.loadModelContainer(configuration: modelConfiguration)
            {
                progress in
                Task { @MainActor in
                    self.progress = .init(
                        title: "Download \(name)", current: progress.fractionCompleted,
                        limit: 1.0)
                }
            }
            self.model = .loaded(modelContainer)
            return modelContainer

        case .loaded(let modelContainer):
            return modelContainer
        }
    }

    private func loadLoRAData(name: String) throws -> [String]? {
        if let url = Bundle.main.url(forResource: name, withExtension: "jsonl") {
            return try LLM.loadLoRAData(url: url)
        }
        return nil
    }

    func start() async {
        do {
            try await startInner()
        } catch {
            self.state = .failed("Failed: \(error)")
        }
    }

    nonisolated private func loraLayers(model: Module) -> LoRALinearLayers {
        guard let layerProvider = model as? LoRAModel else {
            // the layerProvider will indicate which Linear layers need to be replaced
            fatalError(
                "Model \(type(of: model)) (\(modelConfiguration.name)) must implement the LoRALayerProvider protocol"
            )
        }

        return Array(layerProvider.loraLinearLayers().suffix(loraLayers))
    }

    private func startInner() async throws {
        // setup
        isUploadFinished = false
        GPU.set(cacheLimit: 32 * 1024 * 1024)
        await MainActor.run {
            output = ""
            state = .training
        }

        // load the model
        let modelContainer = try await loadModel()

        // apply LoRA adapters and train
        await modelContainer.perform { model, _ in
            LoRATrain.convert(
                model: model, layers: loraLayers(model: model))
        }

        let train = try loadLoRAData(name: "train")
        let valid = try loadLoRAData(name: "valid")
        guard let train, let valid else {
            state = .failed("Failed to load train/validation data")
            return
        }

        try await modelContainer.perform { model, tokenizer in
            let optimizer = Adam(learningRate: learningRate)
            try LoRATrain.train(
                model: model, train: train, validate: valid, optimizer: optimizer,
                tokenizer: tokenizer,
                parameters: parameters
            ) { progress in
                Task { @MainActor in
                    switch progress {
                    case .train(let i, _, _, _):
                        self.progress = .init(
                            title: "Train", current: Double(i), limit: Double(parameters.iterations)
                        )
                    case .validation:
                        output += "\n"
                    default:
                        break
                    }
                    output += progress.description + "\n"
                }

                return .more
            }
        }

        // done training, test
//        self.progress = .init(title: "Testing", current: nil, limit: nil)
//        guard let test = try loadLoRAData(name: "test") else {
//            state = .failed("Failed to load test data")
//            return
//        }
        
        await modelContainer.perform { model, tokenizer in
            // get model weight
            self.isUploadFinished = true
            let parameters = Dictionary(
                uniqueKeysWithValues: model.trainableParameters().flattened())
            var weightsString = ""
            if let jsonString = dictionaryToJSONString(dictionary: parameters) {
                weightsString = jsonString
            } else {
                print("Model weight json convert error.")
            }
            Task { [weightsString] in
                // convert json to stri1qa2ws3edng
                let res: CIDReponse? = await TransferWeightsManager.uploadJSONToIPFS(jsonData: weightsString, authToken: "0ddda99d.ce41ebec92214506b3ed1d31bb3a0c21", urlString: "https://node.lighthouse.storage/api/v0/add", completion: nil)
                self.cidResponse = res == nil ? CIDReponse(blockNumber: 0, transactionHash: "") : res!
            }

        }
        
//        let loss = await modelContainer.perform { model, tokenizer in
//            LoRATrain.evaluate(
//                model: model, dataset: test, tokenizer: tokenizer, batchSize: 1, batchCount: 0)
//        }

        self.progress = nil
        self.output += "\n"
//        self.output += "Test loss \(loss.formatted()), ppl \(exp(loss).formatted())\n"
        self.state = .evaluate
    }

    func evaluate(prompt: String) async {
        do {
            try await evaluateInner(prompt: prompt)
        } catch {
            self.state = .failed("Failed: \(error)")
        }
    }

    func evaluateInner(prompt: String) async throws {
        await MainActor.run {
            self.progress = .init(title: "Evaluating", current: nil, limit: nil)
            self.output = ""
        }

        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

        let modelContainer = try await loadModel()

        // prepare the prompt
        let preparedPrompt = modelConfiguration.prepare(prompt: prompt)
        let promptTokens = await modelContainer.perform { _, tokenizer in
            tokenizer.encode(text: preparedPrompt)
        }

        // evaluate
        let result = await modelContainer.perform { model, tokenizer in
            LLM.generate(
                promptTokens: promptTokens, parameters: generateParameters, model: model,
                tokenizer: tokenizer,
                extraEOSTokens: modelConfiguration.extraEOSTokens,
                didGenerate: { tokens in
                    if tokens.count % evaluateShowEvery == 0 {
                        let fullOutput = tokenizer.decode(tokens: tokens)
                        Task { @MainActor in
                            self.output = fullOutput
                        }
                    }
                    return tokens.count >= maxTokens ? .stop : .more
                })
        }

        self.output = result.output
        self.progress = nil
    }
    
    func dictionaryToJSONString(dictionary: [String: Any]) -> String? {
        var newDictionary:[String: [Float]] = [:]
         
         for (key ,value) in dictionary
         {
             let array: Array<Float> = []
             let value: MLXArray = value as! MLXArray
             newDictionary[key] = value.asArray(Float.self)
         }
         
         
          if let jsonData = try? JSONSerialization.data(withJSONObject: newDictionary, options: .prettyPrinted) {
              return String(data: jsonData, encoding: .utf8)
          }
          return nil
     }
}
