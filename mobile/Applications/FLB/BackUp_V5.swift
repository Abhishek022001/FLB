//// Copyright © 2024 Apple Inc.
//
//import LLM
//import MLX
//import MLXNN
//import MLXOptimizers
//import MLXRandom
//import SwiftUI
//import Tokenizers
//
//
//
//import SwiftUI
//import UIKit
//import ImageIO
//
//struct GIFImage: UIViewRepresentable {
//    let name: String
//
//    func makeUIView(context: Context) -> UIView {
//        let view = UIView()
//        let gifUrl = Bundle.main.url(forResource: name, withExtension: "gif")!
//        let imageSource = CGImageSourceCreateWithURL(gifUrl as CFURL, nil)!
//        let imageCount = CGImageSourceGetCount(imageSource)
//
//        var images: [UIImage] = []
//        for index in 0..<imageCount {
//            if let image = CGImageSourceCreateImageAtIndex(imageSource, index, nil) {
//                images.append(UIImage(cgImage: image))
//            }
//        }
//
//        let imageView = UIImageView()
//        imageView.animationImages = images
//        imageView.animationDuration = Double(imageCount) / 26 // 控制速度
//        imageView.startAnimating()
//
//        view.addSubview(imageView)
//        imageView.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            imageView.topAnchor.constraint(equalTo: view.topAnchor),
//            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
//        ])
//
//        return view
//    }
//
//    func updateUIView(_ uiView: UIView, context: Context) {
//        // 更新视图
//    }
//}
//
//
//
////// // // // // /// // // // // // // /// // // 可视化界面 V1 // // // // // // // //// // // // // // // //// // // // // // // //
////
////import SwiftUI
////
////struct ContentView: View {
////    @State var evaluator = LoRAEvaluator()
////    @State var prompt = """
////        table: 1-10015132-16
////        columns: Player, No., Nationality, Position, Years in Toronto, School/Club Team
////        Q: What is terrence ross' nationality
////        A:
////        """
////    @State private var showText = false
////
////    var body: some View {
////        VStack {
////            Spacer()
////
////            if showText {
////                Text("Empowering the Future of Data Privacy and Security: The Integration of Blockchain and Federated Learning")
////                    .font(.title2)
////                    .fontWeight(.bold)
////                    .multilineTextAlignment(.center)
////                    .transition(.scale)
////                    .animation(.easeIn(duration: 1))
////                    .foregroundColor(.blue)
////                    .padding()
////            }
////
////            Spacer()
////
////            // 其他视图组件
////            VStack {
////                // 进度视图
////                if let progress = evaluator.progress {
////                    ProgressView(progress.title, value: progress.current ?? 0, total: progress.limit ?? 1)
////                        .frame(maxWidth: .infinity, minHeight: 25)
////                }
////
////                // 插入GIF视图
////                GIFImage(name: "main_pic5")
////                    .frame(height: 300)
////
////                // 输出滚动视图
////                ScrollView {
////                    ScrollViewReader { sp in
////                        Text(evaluator.output)
////                            .textSelection(.enabled)
////                            .frame(maxWidth: .infinity)
////                            .padding()
////                            .onChange(of: evaluator.output) { _, _ in
////                                sp.scrollTo("bottom")
////                            }
////
////                        Spacer()
////                            .frame(width: 1, height: 1)
////                            .id("bottom")
////                    }
////                }
////
////                // 状态控制按钮
////                stateControlButtons()
////            }
////        }
////        .padding()
////        .onAppear {
////            withAnimation {
////                showText.toggle() // 触发广告语显示动画
////            }
////        }
////    }
////
////    // 状态控制按钮视图
////    @MainActor
////    private func stateControlButtons() -> some View {
////        Group { // 使用 Group 以确保返回相同的类型
////            switch evaluator.state {
////            case .idle:
////                Button(action: start) {
////                    Label("Start", systemImage: "play.fill")
////                        .padding()
////                        .background(Color.green)
////                        .foregroundColor(.white)
////                        .cornerRadius(10)
////                        .shadow(radius: 5)
////                }
////                .disabled(evaluator.progress != nil)
////
////            case .training:
////                EmptyView()
////
////            case .evaluate:
////                VStack {
////                    TextEditor(text: $prompt)
////                        .frame(minHeight: 60)
////                    Button("Evaluate", action: evaluate)
////                }
////                .disabled(evaluator.progress != nil)
////
////            case .failed(let message):
////                Text("Failed: \(message)")
////                    .bold()
////                    .foregroundColor(.red)
////            }
////        }
////    }
////
////    // 启动和评估的异步任务
////    @MainActor // 确保这些方法在主线程执行
////    func start() {
////        Task {
////            await evaluator.start()
////        }
////    }
////
////    @MainActor // 确保这些方法在主线程执行
////    func evaluate() {
////        Task {
////            await evaluator.evaluate(prompt: prompt)
////        }
////    }
////}
//
//
//
//
//
//
//
//
//
//// // // // // /// // // // // // // /// // // 可视化界面 V4 // // // // // // // //// // // // // // // //// // // // // // // //
//
//
//
//class FrameRateMonitor: ObservableObject {
//    @Published var frameRate: Double = 0.0
//    private var displayLink: CADisplayLink?
//
//    func startMonitoring() {
//        displayLink = CADisplayLink(target: self, selector: #selector(updateFrameRate))
//        displayLink?.add(to: .main, forMode: .default)
//    }
//
//    func stopMonitoring() {
//        displayLink?.invalidate()
//        displayLink = nil
//    }
//
//    @objc private func updateFrameRate() {
//        if let displayLink = displayLink {
//            frameRate = 1 / displayLink.duration
//        }
//    }
//}
//
//
//import Foundation
//import SwiftUI
//
// 
//func getCPUUsage() -> Double {
//    var threadsArray: thread_act_array_t?
//    var threadCount = mach_msg_type_number_t()
//
//    let kr = task_threads(mach_task_self_, &threadsArray, &threadCount)
//    if kr != KERN_SUCCESS {
//        return -1
//    }
//
//    var totalCPUUsage: Double = 0.0
//
//    if let threads = threadsArray {
//        for i in 0..<threadCount {
//            var threadInfo = thread_basic_info_data_t()
//            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
//
//            let kr = withUnsafeMutablePointer(to: &threadInfo) {
//                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
//                    thread_info(threads[Int(i)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
//                }
//            }
//
//            if kr == KERN_SUCCESS {
//                if threadInfo.flags != TH_FLAGS_IDLE {
//                    totalCPUUsage += (Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
//                }
//            }
//        }
//        // 释放线程列表
//        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(threadCount))
//    }
//
//    return totalCPUUsage
//}
//
//
//
//
//
//func getMemoryUsage() -> UInt64 {
//    var info = mach_task_basic_info()
//    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
//
//    let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
//        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
//            kern_return_t(task_info(mach_task_self_,
//                                    task_flavor_t(MACH_TASK_BASIC_INFO),
//                                    $0,
//                                    &count))
//        }
//    }
//
//    if result == KERN_SUCCESS {
//        return info.resident_size // 返回当前内存占用，单位为字节
//    } else {
//        return 0 // 返回 0 表示获取失败
//    }
//}
//
//
//
//
//
//
//
//
//
//
//import SwiftUI
//
//struct SystemUsageView: View {
//    @State private var cpuUsage: Double = 0.0
//    @State private var memoryUsage: UInt64 = 0
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            Text("CPU Usage: \(String(format: "%.2f", cpuUsage))%")
//                .font(.headline)
//
//            Text("Memory Usage: \(memoryUsage / 1024 / 1024) MB")
//                .font(.headline)
//            
//            Button("Refresh System Info") {
//                cpuUsage = getCPUUsage()
//                memoryUsage = getMemoryUsage()
//            }
//            .padding()
//            .background(Color.blue)
//            .foregroundColor(.white)
//            .cornerRadius(10)
//        }
//        .padding()
//        .onAppear {
//            // 获取当前系统信息
//            cpuUsage = getCPUUsage()
//            memoryUsage = getMemoryUsage()
//        }
//    }
//}
//
//
//
//
//
//import SwiftUI
//
//struct ContentView: View {
//    @State var evaluator = LoRAEvaluator()
//    @State var prompt = """
//        table: 1-10015132-16
//        columns: Player, No., Nationality, Position, Years in Toronto, School/Club Team
//        Q: What is terrence ross' nationality
//        A:
//        """
//    @State private var showText = false
//    @State private var logOutput = "" // 用于显示的日志输出
//
//    // 动态渐变的颜色数组
//    @State private var gradientColors: [Color] = [Color.white, Color.mint.opacity(0.5), Color.blue.opacity(0.3), Color.green.opacity(0.4)]
//
//
//
//    @State private var frameRate: Double = 0.0
//    @State private var displayLink: CADisplayLink?
//    @StateObject private var frameRateMonitor = FrameRateMonitor()
//
//
//
//    var body: some View {
//        ZStack {
//            // 动态的渐变背景，颜色会不断变化
//            LinearGradient(gradient: Gradient(colors: gradientColors),
//                           startPoint: .topLeading,
//                           endPoint: .bottomTrailing)
//                .ignoresSafeArea()
//                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) // 动态渐变
//
//            
//             
//        VStack {
//            // TabView 用于滑动毛玻璃区域
//            TabView {
//                // 第一块毛玻璃视图
//                BlurView()
//                    .frame(height: 550) // 调整毛玻璃的高度
//                    .cornerRadius(20)
//                    .overlay(
//                        VStack(spacing: 10) {
//                            GIFImage(name: "main_pic5")
//                                .frame(height: 300)
//
//                            // 第一段广告语，显示在GIF下方
//                            Text("Revolutionizing Data Privacy for a Transparent and Secure Tomorrow")
//                                .font(.title2)
//                                .fontWeight(.bold)
//                                .multilineTextAlignment(.center)
//                                .padding(.horizontal, 15)
//                                .foregroundColor(.black)
//
//                            // 第二段广告语
//                            LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .leading, endPoint: .trailing)
//                                .mask(
//                                    VStack {
//                                        Text("Powered by Blockchain")
//                                            .font(.headline)
//                                            .multilineTextAlignment(.center)
//                                        Text("and Federated Learning")
//                                            .font(.headline)
//                                            .multilineTextAlignment(.center)
//                                    }
//                                )
//                                .frame(height: 80) // 设置文本的高度
//                        }
//                    )
//                    .padding(.horizontal)
//                    .padding(.top, -50) // 调整 top padding 以确保内容不被遮挡
//
//                
//                
//                // 第二块毛玻璃视图（动态显示帧率信息）
//                BlurView()
//                    .frame(height: 550)
//                    .cornerRadius(20)
//                    .overlay(
//                        VStack(spacing: 10) {
////                            GIFImage(name: "main_pic5")
////                                .frame(height: 300)
//
////                            // 第二段广告语
////                            Text("Ensuring Future Data Privacy and Trust Through Decentralization")
////                                .font(.title2)
////                                .fontWeight(.bold)
////                                .multilineTextAlignment(.center)
////                                .padding(.horizontal, 15)
////                                .foregroundColor(.black)
////
////                            LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .leading, endPoint: .trailing)
////                                .mask(
////                                    VStack {
////                                        Text("Secured by Blockchain")
////                                            .font(.headline)
////                                            .multilineTextAlignment(.center)
////                                        Text("and AI-Powered Solutions")
////                                            .font(.headline)
////                                            .multilineTextAlignment(.center)
////                                    }
////                                )
////                                .frame(height: 80)
//
//                            SystemUsageView()
//                            // 动态显示帧率（GPU 信息）
//                            Text("Current Frame Rate: \(String(format: "%.2f", frameRateMonitor.frameRate)) FPS")
//                                .font(.headline)
//                                .multilineTextAlignment(.center)
//                                .padding(.top, 10)
//                                .foregroundColor(.black) // 显示帧率信息
//                        }
//                    )
//                    .padding(.horizontal)
//                    .padding(.top, -50)
//                    .onAppear {
//                        frameRateMonitor.startMonitoring()
//                    }
//                    .onDisappear {
//                        frameRateMonitor.stopMonitoring()
//                    }
//
//                // 第三块毛玻璃视图
//                BlurView()
//                    .frame(height: 550)
//                    .cornerRadius(20)
//                    .overlay(
//                        VStack(spacing: 10) {
//                            GIFImage(name: "main_pic5")
//                                .frame(height: 300)
//
//                            // 第三段广告语
//                            Text("Innovating the Future of Secure Data Sharing")
//                                .font(.title2)
//                                .fontWeight(.bold)
//                                .multilineTextAlignment(.center)
//                                .padding(.horizontal, 15)
//                                .foregroundColor(.black)
//
//                            LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .leading, endPoint: .trailing)
//                                .mask(
//                                    VStack {
//                                        Text("Blockchain-Driven Security")
//                                            .font(.headline)
//                                            .multilineTextAlignment(.center)
//                                        Text("with Cutting-Edge Technology")
//                                            .font(.headline)
//                                            .multilineTextAlignment(.center)
//                                    }
//                                )
//                                .frame(height: 80)
//                        }
//                    )
//                    .padding(.horizontal)
//                    .padding(.top, -50)
//            }
//            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always)) // 实现滑动效果和分页指示
//            .frame(height: 650) // 设置滑动视图的高度
//
//            Spacer()
//
//            // 底部内容（进度条和日志输出）
//            VStack {
//                if let progress = evaluator.progress {
//                    ProgressView(progress.title, value: progress.current ?? 0, total: progress.limit ?? 1)
//                        .frame(maxWidth: .infinity, minHeight: 25)
//                        .padding()
//                }
//
//                ScrollView {
//                    ScrollViewReader { sp in
//                        Text(evaluator.output + "\n" + logOutput)
//                            .textSelection(.enabled)
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .onChange(of: evaluator.output) { _, _ in
//                                sp.scrollTo("bottom")
//                            }
//                            .onChange(of: logOutput) { _ in
//                                sp.scrollTo("bottom")
//                            }
//                        Spacer()
//                            .frame(width: 1, height: 1)
//                            .id("bottom")
//                    }
//                }
//
//                stateControlButtons()
//            }
//            .padding()
//        }
//        .onAppear {
//            withAnimation {
//                showText.toggle()
//            }
//            startDynamicGradientChange()
//        }
//    }
//    }
//
//
// 
//    
//
//
//    // 使用定时器定期更新渐变颜色，实现动态效果
//    func startDynamicGradientChange() {
//        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
//            withAnimation(.easeInOut(duration: 3)) {
//                // 每次改变渐变颜色
//                gradientColors = gradientColors.shuffled() // 随机打乱颜色顺序
//            }
//        }
//    }
//
//
//
//
//
//    @MainActor
//    private func stateControlButtons() -> some View {
//        Group { // 使用 Group 以确保返回相同的类型
//            switch evaluator.state {
//            case .idle:
//                Button(action: start) {
//                    Label("Start", systemImage: "play.fill")
//                        .padding()
//                        .background(Color.green)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                        .shadow(radius: 5)
//                }
//                .disabled(evaluator.progress != nil)
//
//            case .training:
//                EmptyView()
//
//            case .evaluate:
//                VStack {
//                    TextEditor(text: $prompt)
//                        .frame(minHeight: 60)
//                    Button("Evaluate", action: evaluate)
//                }
//                .disabled(evaluator.progress != nil)
//
//            case .failed(let message):
//                Text("Failed: \(message)")
//                    .bold()
//                    .foregroundColor(.red)
//            }
//        }
//    }
//
//    // 启动和评估的异步任务
//    @MainActor // 确保这些方法在主线程执行
//    func start() {
//        Task {
//            await evaluator.start()
//        }
//    }
//
//    @MainActor // 确保这些方法在主线程执行
//    func evaluate() {
//        Task {
//            await evaluator.evaluate(prompt: prompt)
//        }
//    }
//
//
//    private func logAction(_ message: String) {
//        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
//        logOutput += "[\(timestamp)] \(message)\n"
//    }
//
//    struct BlurView: UIViewRepresentable {
//        func makeUIView(context: Context) -> UIVisualEffectView {
//            let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
//            view.alpha = 0.7
//            return view
//        }
//
//        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
//    }
//}
//
//
//
//
//
//
//
//
//
//
//
//
///// Progress reporting with a title.
//struct Progress: Equatable, Sendable {
//    let title: String
//    let current: Double?
//    let limit: Double?
//}
//
//
//
//
//
//
//
////@Observable
////@MainActor
////class LoRAEvaluator {
////
////    enum State: Sendable {
////        case idle
////        case training
////        case evaluate
////        case failed(String)
////    }
////
////    enum ModelState: Sendable {
////        case idle
////        case loaded(ModelContainer)
////    }
////
////    var state = State.idle
////    var progress: Progress?
////
////    var output = ""
////
////    private let modelConfiguration = ModelConfiguration.smolLM_135M_4bit
////    private var model: ModelState = .idle
////
////    private let loraLayers = 4
////    private let learningRate: Float = 1e-5
////    private let parameters = LoRATrain.Parameters(batchSize: 1, iterations: 200)
////
////    private let generateParameters = GenerateParameters(temperature: 0.6, topP: 0.9)
////    private let evaluateShowEvery = 8
////    private let maxTokens = 200
////
////
////
////
////    private func loadModel() async throws -> ModelContainer {
////        switch self.model {
////        case .idle:
////            let name = modelConfiguration.name
////            await MainActor.run {
////                progress = .init(title: "Loading \(name)", current: 0, limit: 1)
////            }
////
////            let modelContainer = try await LLM.loadModelContainer(configuration: modelConfiguration)
////            {
////                progress in
////                Task { @MainActor in
////                    self.progress = .init(
////                        title: "Download \(name)", current: progress.fractionCompleted,
////                        limit: 1.0)
////                }
////            }
////            self.model = .loaded(modelContainer)
////            return modelContainer
////
////        case .loaded(let modelContainer):
////            return modelContainer
////        }
////    }
//
//
//
//
//
//
//
//// LoRAEvaluator 模型加载类
//@Observable
//@MainActor
//class LoRAEvaluator {
//
//    enum State: Sendable {
//        case idle
//        case training
//        case evaluate
//        case failed(String)
//    }
//
//    enum ModelState: Sendable {
//        case idle
//        case loaded(ModelContainer)
//    }
//
//    var state = State.idle
//    var progress: Progress?
//
//    var output = ""
//
//    private let modelConfiguration = ModelConfiguration.smolLM_135M_4bit
//    private var model: ModelState = .idle
//
//    private let loraLayers = 4
//    private let learningRate: Float = 1e-5
//    private let parameters = LoRATrain.Parameters(batchSize: 1, iterations: 2000)
//
//    private let generateParameters = GenerateParameters(temperature: 0.6, topP: 0.9)
//    private let evaluateShowEvery = 8
//    private let maxTokens = 200
//
//    // 加载模型并显示进度
//    func loadModel() async throws -> ModelContainer {
//        switch self.model {
//        case .idle:
//            let name = modelConfiguration.name
//            // 更新进度条的标题，显示加载状态
//            await MainActor.run {
//                progress = .init(title: "Loading \(name)", current: 0, limit: 1)
//            }
//
//            // 加载模型，并追踪下载进度
//            let modelContainer = try await LLM.loadModelContainer(configuration: modelConfiguration) {
//                progress in
//                Task { @MainActor in
//                    // 更新进度条的状态
//                    self.progress = .init(
//                        title: "Downloading \(name)",
//                        current: progress.fractionCompleted,
//                        limit: 1.0
//                    )
//                }
//            }
//
//            // 模型加载完成，更新状态
//            self.model = .loaded(modelContainer)
//            return modelContainer
//
//        case .loaded(let modelContainer):
//            return modelContainer
//        }
//    }
//
//
//
//    private func loadLoRAData(name: String) throws -> [String]? {
//        if let url = Bundle.main.url(forResource: name, withExtension: "jsonl") {
//            return try LLM.loadLoRAData(url: url)
//        }
//        return nil
//    }
//
//    func start() async {
//        do {
//            try await startInner()
//        } catch {
//            self.state = .failed("Failed: \(error)")
//        }
//    }
//
//    nonisolated private func loraLayers(model: Module) -> LoRALinearLayers {
//        guard let layerProvider = model as? LoRAModel else {
//            // the layerProvider will indicate which Linear layers need to be replaced
//            fatalError(
//                "Model \(type(of: model)) (\(modelConfiguration.name)) must implement the LoRALayerProvider protocol"
//            )
//        }
//
//        return Array(layerProvider.loraLinearLayers().suffix(loraLayers))
//    }
//
//    private func startInner() async throws {
//        // setup
//        GPU.set(cacheLimit: 32 * 1024 * 1024)
//        await MainActor.run {
//            output = ""
//            state = .training
//        }
//
//        // load the model
//        let modelContainer = try await loadModel()
//
//        // apply LoRA adapters and train
//        await modelContainer.perform { model, _ in
//            LoRATrain.convert(
//                model: model, layers: loraLayers(model: model))
//        }
//
//        let train = try loadLoRAData(name: "train")
//        let valid = try loadLoRAData(name: "valid")
//        guard let train, let valid else {
//            state = .failed("Failed to load train/validation data")
//            return
//        }
//
//        try await modelContainer.perform { model, tokenizer in
//            let optimizer = Adam(learningRate: learningRate)
//            try LoRATrain.train(
//                model: model, train: train, validate: valid, optimizer: optimizer,
//                tokenizer: tokenizer,
//                parameters: parameters
//            ) { progress in
//                Task { @MainActor in
//                    switch progress {
//                    case .train(let i, _, _, _):
//                        self.progress = .init(
//                            title: "Train", current: Double(i), limit: Double(parameters.iterations)
//                        )
//                    case .validation:
//                        output += "\n"
//                    default:
//                        break
//                    }
//                    output += progress.description + "\n"
//                }
//
//                return .more
//            }
//        }
//
//        // done training, test
//        self.progress = .init(title: "Testing", current: nil, limit: nil)
//        guard let test = try loadLoRAData(name: "test") else {
//            state = .failed("Failed to load test data")
//            return
//        }
//
//        let loss = await modelContainer.perform { model, tokenizer in
//            LoRATrain.evaluate(
//                model: model, dataset: test, tokenizer: tokenizer, batchSize: 1, batchCount: 0)
//        }
//
//        self.progress = nil
//        self.output += "\n"
//        self.output += "Test loss \(loss.formatted()), ppl \(exp(loss).formatted())\n"
//        self.state = .evaluate
//    }
//
//    func evaluate(prompt: String) async {
//        do {
//            try await evaluateInner(prompt: prompt)
//        } catch {
//            self.state = .failed("Failed: \(error)")
//        }
//    }
//
//    func evaluateInner(prompt: String) async throws {
//        await MainActor.run {
//            self.progress = .init(title: "Evaluating", current: nil, limit: nil)
//            self.output = ""
//        }
//
//        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
//
//        let modelContainer = try await loadModel()
//
//        // prepare the prompt
//        let preparedPrompt = modelConfiguration.prepare(prompt: prompt)
//        let promptTokens = await modelContainer.perform { _, tokenizer in
//            tokenizer.encode(text: preparedPrompt)
//        }
//
//        // evaluate
//        let result = await modelContainer.perform { model, tokenizer in
//            LLM.generate(
//                promptTokens: promptTokens, parameters: generateParameters, model: model,
//                tokenizer: tokenizer,
//                extraEOSTokens: modelConfiguration.extraEOSTokens,
//                didGenerate: { tokens in
//                    if tokens.count % evaluateShowEvery == 0 {
//                        let fullOutput = tokenizer.decode(tokens: tokens)
//                        Task { @MainActor in
//                            self.output = fullOutput
//                        }
//                    }
//                    return tokens.count >= maxTokens ? .stop : .more
//                })
//        }
//
//        self.output = result.output
//        self.progress = nil
//    }
//}
