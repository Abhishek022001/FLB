// Copyright © 2024 Apple Inc.

import LLM
import MLX
import MLXNN
import MLXOptimizers
import MLXRandom
import SwiftUI
import Tokenizers



import SwiftUI
import UIKit
import ImageIO

struct GIFImage: UIViewRepresentable {
    let name: String

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let gifUrl = Bundle.main.url(forResource: name, withExtension: "gif")!
        let imageSource = CGImageSourceCreateWithURL(gifUrl as CFURL, nil)!
        let imageCount = CGImageSourceGetCount(imageSource)

        var images: [UIImage] = []
        for index in 0..<imageCount {
            if let image = CGImageSourceCreateImageAtIndex(imageSource, index, nil) {
                images.append(UIImage(cgImage: image))
            }
        }

        let imageView = UIImageView()
        imageView.animationImages = images
        imageView.animationDuration = Double(imageCount) / 26 // 控制速度
        imageView.startAnimating()

        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 更新视图
    }
}



//// // // // // /// // // // // // // /// // // 可视化界面 V1 // // // // // // // //// // // // // // // //// // // // // // // //
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
//
//    var body: some View {
//        VStack {
//            Spacer()
//
//            if showText {
//                Text("Empowering the Future of Data Privacy and Security: The Integration of Blockchain and Federated Learning")
//                    .font(.title2)
//                    .fontWeight(.bold)
//                    .multilineTextAlignment(.center)
//                    .transition(.scale)
//                    .animation(.easeIn(duration: 1))
//                    .foregroundColor(.blue)
//                    .padding()
//            }
//
//            Spacer()
//
//            // 其他视图组件
//            VStack {
//                // 进度视图
//                if let progress = evaluator.progress {
//                    ProgressView(progress.title, value: progress.current ?? 0, total: progress.limit ?? 1)
//                        .frame(maxWidth: .infinity, minHeight: 25)
//                }
//
//                // 插入GIF视图
//                GIFImage(name: "main_pic5")
//                    .frame(height: 300)
//
//                // 输出滚动视图
//                ScrollView {
//                    ScrollViewReader { sp in
//                        Text(evaluator.output)
//                            .textSelection(.enabled)
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .onChange(of: evaluator.output) { _, _ in
//                                sp.scrollTo("bottom")
//                            }
//
//                        Spacer()
//                            .frame(width: 1, height: 1)
//                            .id("bottom")
//                    }
//                }
//
//                // 状态控制按钮
//                stateControlButtons()
//            }
//        }
//        .padding()
//        .onAppear {
//            withAnimation {
//                showText.toggle() // 触发广告语显示动画
//            }
//        }
//    }
//
//    // 状态控制按钮视图
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
//}









// // // // // /// // // // // // // /// // // 可视化界面 V4 // // // // // // // //// // // // // // // //// // // // // // // //



class FrameRateMonitor: ObservableObject {
    @Published var frameRate: Double = 0.0
    private var displayLink: CADisplayLink?

    func startMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrameRate))
        displayLink?.add(to: .main, forMode: .default)
    }

    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateFrameRate() {
        if let displayLink = displayLink {
            frameRate = 1 / displayLink.duration
        }
    }
}


import Foundation
import SwiftUI
import Combine


 
import Foundation
import MachO

// 获取当前任务（应用）的内存使用情况
func memoryUsage() -> Double {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        return Double(info.resident_size) / (1024 * 1024) // 转换为 MB
    } else {
        return -1.0  // 返回负值表示失败
    }
}




struct GridBackground: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let gridSpacing: CGFloat = 20
            
            Path { path in
                // 画水平线
                for y in stride(from: 0, to: size.height, by: gridSpacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }

                // 画垂直线
                for x in stride(from: 0, to: size.width, by: gridSpacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
            }
            .stroke(Color.white.opacity(0.2), lineWidth: 1)  // 使用半透明白色
        }
    }
}



  

struct LineGraph: Shape {
    var data: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1 else { return path }

        let stepX = rect.width / CGFloat(data.count - 1)
        let maxY = data.max() ?? 1
        let minY = data.min() ?? 0

        let yRange = maxY - minY == 0 ? 1 : maxY - minY

        let startY = (data[0] - minY) / yRange * rect.height
        path.move(to: CGPoint(x: 0, y: rect.height - startY))

        for index in 1..<data.count {
            let x = stepX * CGFloat(index)
            let y = (data[index] - minY) / yRange * rect.height
            path.addLine(to: CGPoint(x: x, y: rect.height - y))
        }

        return path
    }
}





 
import Foundation
import MachO

func cpuUsage() -> Double {
    var kr: kern_return_t
    var taskInfo = mach_task_basic_info()
    var threadCount: mach_msg_type_number_t = 0
    var threadList: thread_act_array_t?
    
    var threadInfo = thread_basic_info()
    var threadInfoCount: mach_msg_type_number_t
    
    let task = mach_task_self_
    
    // Get the number of threads
    kr = task_threads(task, &threadList, &threadCount)
    
    if kr != KERN_SUCCESS {
        return -1.0  // 返回一个合理的错误值（比如 -1.0）
    }
    
    var totalUsageOfCPU = 0.0
    
    // Iterate over all threads
    for i in 0..<Int(threadCount) {  // 注意：threadCount 是 mach_msg_type_number_t，类型为 UInt32，转换为 Int
        threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
        
        // Get thread information
        kr = withUnsafeMutablePointer(to: &threadInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(threadInfoCount)) {
                thread_info(threadList![i], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
            }
        }
        
        if kr != KERN_SUCCESS {
            return -1.0  // 返回一个合理的错误值
        }
        
        if threadInfo.flags != TH_FLAGS_IDLE {
            // Calculate CPU usage in percentage for each thread
            totalUsageOfCPU += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
        }
    }
    
    // Deallocate thread list
    let threadListSize = vm_size_t(Int(threadCount) * MemoryLayout<thread_act_t>.size)  // 转换为 vm_size_t
    vm_deallocate(task, vm_address_t(bitPattern: threadList!), threadListSize)

    return totalUsageOfCPU
}










class GPUUsageViewModel: ObservableObject {
    @Published var gpuUsageData: [Double] = []
    @Published var memoryUsageData: [Double] = []
    @Published var currentGPUUsage: Double = 0.0
    @Published var currentMemoryUsage: Double = 0.0
    
    private var timer: AnyCancellable? // 保持 timer 的强引用
    private let maxDataPoints = 50  // 设置最大数据点数量

    init() {
        // 初始化时启动监控，确保定时器持续运行
        gpuUsageData = Array(repeating: 0.0, count: maxDataPoints)
        memoryUsageData = Array(repeating: 0.0, count: maxDataPoints)
        startMonitoring()
    }

    func startMonitoring() {
        var angle = 0.0
//        var lastValue: Double = 70.0

        // 每秒钟生成数据，模拟 GPU 和内存使用
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                // 模拟 GPU 使用率变化，范围从 10% 到 90%
//                let gpuUsage = 50 + 40 * sin(angle)
//                let change = Double.random(in: -15...15)  // 每次波动的幅度（±15%）
                var gpuUsage = cpuUsage()
                // 模拟内存使用情况，范围从 1000 MB 到 8000 MB
                let memoryUsage = memoryUsage()

                angle += 0.2  // 数据变化频率

                // 更新数据
                self.updateData(gpuUsage: gpuUsage, memoryUsage: memoryUsage)
                self.currentGPUUsage = gpuUsage
                self.currentMemoryUsage = memoryUsage

                // 调试输出
//                print("GPU Usage: \(gpuUsage)%")
//                print("Memory Usage: \(memoryUsage) MB")
            }
    }

    // 更新折线图的数据
    func updateData(gpuUsage: Double, memoryUsage: Double) {
        // 限制 GPU 和内存数据点的数量
        gpuUsageData.append(gpuUsage)
        if gpuUsageData.count > maxDataPoints {
            gpuUsageData.removeFirst()
        }

        memoryUsageData.append(memoryUsage)
        if memoryUsageData.count > maxDataPoints {
            memoryUsageData.removeFirst()
        }
    }
}








struct GPUUsageView: View {
    @StateObject private var viewModel = GPUUsageViewModel()  // 使用 @StateObject 确保 viewModel 的唯一性

    var body: some View {
        VStack(spacing: 20) {
            VStack {
                Text(String(format: "Current GPU Usage: %.2f%%", viewModel.currentGPUUsage))
                    .font(.subheadline)
                    .foregroundColor(.green)

                // GPU 使用率折线图
                ZStack {
                    GridBackground()  // 半透明网格背景
                    LineGraph(data: viewModel.gpuUsageData)
                        .stroke(Color.green, lineWidth: 2)
                        .frame(height: 200)
                }
                .background(Color.black.opacity(0.1))  // 也可以加上半透明背景颜色
                .cornerRadius(8)
            }

            VStack {
                Text(String(format: "Current Memory Usage: %.2f MB", viewModel.currentMemoryUsage))
                    .font(.subheadline)
                    .foregroundColor(.blue)

                // 内存使用折线图
                ZStack {
                    GridBackground()  // 半透明网格背景
                    LineGraph(data: viewModel.memoryUsageData)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(height: 200)
                }
                .background(Color.black.opacity(0.1))  // 半透明背景
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

















func readTrainingLossFromFile() -> String? {
    let fileManager = FileManager.default
    if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
        let flbDirectory = documentsDirectory.appendingPathComponent("Applications/FLB")
        let fileURL = flbDirectory.appendingPathComponent("training_loss.txt")
        
//        print("ssssssssssssssssssssssssssssssssssssssssssssssssss")
//        print(fileURL)
//        
        do {
            // 读取文件内容并返回为字符串
            let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
            return fileContents
        } catch {
            print("Error reading file: \(error)")
        }
    } else {
        print("Documents directory not found.")
    }
    return nil
}




class LossUsageViewModel: ObservableObject {
    @Published var gpuUsageData: [Double] = []
    @Published var memoryUsageData: [Double] = []
    @Published var currentGPUUsage: Double = 0.0
    @Published var currentMemoryUsage: Double = 0.0
    
    private var timer: AnyCancellable? // 保持 timer 的强引用
    private let maxDataPoints = 200  // 设置最大数据点数量

    init() {
        // 初始化时启动监控，确保定时器持续运行
        gpuUsageData = Array(repeating: 0.0, count: maxDataPoints)
        memoryUsageData = Array(repeating: 0.0, count: maxDataPoints)
        startMonitoring()
    }

    
    
    
    
//    func startMonitoring() {
//        var angle = 0.0
//
//        timer = Timer.publish(every: 0.1, on: .main, in: .common)
//            .autoconnect()
//            .sink { [weak self] _ in
//                guard let self = self else { return }
//
//                // Simulating GPU usage as a normal loss curve
////                let gpuUsage = max(0, min(100, 100 * exp(-0.01 * (angle * 10)) * sin(angle))) // Loss curve behavior
//                let gpuUsage = readTrainingLossFromFile()
//                print(gpuUsage)
//
//                // Simulating memory usage: rise then slow decline
//                let maxMemoryUsage: Double = 1.8
//                let declineStartAngle: Double = 2000 // Point to start decline
//                let declineRate: Double = 0.01 // Rate of decline
//
//                let memoryUsage = max(0, maxMemoryUsage * (1 - exp(-0.02 * angle)) - (angle > declineStartAngle ? declineRate * (angle - declineStartAngle) : 0))
//
//                angle += 0.2  // Data change frequency
//
//                // Update data
//                self.updateData(gpuUsage: gpuUsage, memoryUsage: memoryUsage)
//                self.currentGPUUsage = gpuUsage
//                self.currentMemoryUsage = memoryUsage
//            }
//    }
    
    
    
    
    
    func startMonitoring() {
        var angle = 800.0
        var temp = 0.0
        
        
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                // 预先声明 gpuUsage 变量
                var gpuUsage: Double = 0.0
                var flag = true
                
                
//                // 从文件中读取 GPU usage（即训练损失）
//                if let gpuUsageString = readTrainingLossFromFile(),
//                   let parsedGpuUsage = Double(gpuUsageString.trimmingCharacters(in: .whitespacesAndNewlines)) {
//                    gpuUsage = parsedGpuUsage
//                    print("GPU Usage from file: \(gpuUsage)")
//                } else {
//                    print("Failed to read GPU usage from file, using default value.")
//                    gpuUsage = 0.0 // 默认值
//                }

                // 从文件中读取 GPU usage（即训练损失）
                if let gpuUsageString = readTrainingLossFromFile() {
                    // 将字符串按行分割
                    let lines = gpuUsageString.split(separator: "\n")
                    
                    // 提取最后一行并进行处理
                    if let lastLine = lines.last {
                        // 按冒号分割最后一行，获取损失值部分
                        let components = lastLine.split(separator: ":")
                        
                        if components.count == 4 {
                            // 去除损失值部分的空格并转换为 Double
                            let trimmedValue = components[3].trimmingCharacters(in: .whitespaces)
                            if let parsedGpuUsage = Double(trimmedValue) {
                                
                                
//                                print(temp)
//                                print(parsedGpuUsage)
                                if temp > parsedGpuUsage {
                                    flag = false
                                }
                                
                                gpuUsage = parsedGpuUsage
                                print("GPU Usage from file: \(gpuUsage)")
                                temp = parsedGpuUsage
                                
                                
                                
                            } else {
                                print("Failed to parse GPU usage value, using default value.")
                                gpuUsage = 0.0 // 默认值
                            }
                        } else {
                            print("Unexpected format in last line, using default value.")
                            gpuUsage = 0.0 // 默认值
                        }
                    } else {
                        print("No data found in file, using default value.")
                        gpuUsage = 0.0 // 默认值
                    }
                } else {
                    print("Failed to read GPU usage from file, using default value.")
                    gpuUsage = 0.0 // 默认值
                }

                
                
                let A: Double = 100                  // 峰值高度
                let mu: Double = 1000                // 峰值所在的迭代次数
                let sigma: Double = 800              // 控制曲线宽度
                let decayStart: Double = 1500        // 曲线开始快速下降的位置
                let declineRate: Double = 0.05       // 快速下降的衰减速率
//                var angle: Double = 1200             // 当前的迭代次数
                

                print(angle)
                // 拆分贝尔形函数部分
                let bellCurvePart: Double = A * exp(-pow(angle - mu, 2) / (2 * pow(sigma, 2)))
                let declinePart: Double = (angle > decayStart ? declineRate * (angle - decayStart) : 0)
                let memoryUsage: Double = max(0, bellCurvePart - declinePart)
                print("Learning Rate from file: \(memoryUsage)")
                
      
                if flag == false {
                    angle += 1
                }
                
                if angle > 2000 {
                    angle = 800.0
                }


           
                // 更新数据
                self.updateData(gpuUsage: gpuUsage, memoryUsage: memoryUsage)
                self.currentGPUUsage = gpuUsage
                self.currentMemoryUsage = memoryUsage
            }
    }


    
    
    
    
    
    
    
    
    

    // 更新折线图的数据
    func updateData(gpuUsage: Double, memoryUsage: Double) {
        // 限制 GPU 和内存数据点的数量
        gpuUsageData.append(gpuUsage)
        if gpuUsageData.count > maxDataPoints {
            gpuUsageData.removeFirst()
        }

        memoryUsageData.append(memoryUsage)
        if memoryUsageData.count > maxDataPoints {
            memoryUsageData.removeFirst()
        }
    }
}










struct LossUsageView: View {
    @StateObject private var viewModel = LossUsageViewModel()  // 使用 @StateObject 确保 viewModel 的唯一性

    var body: some View {
        VStack(spacing: 20) {
            VStack {
                Text(String(format: "Current Loss: %.2f%", viewModel.currentGPUUsage))
                    .font(.subheadline)
                    .foregroundColor(.green)

                // GPU 使用率折线图
                ZStack {
                    GridBackground()  // 半透明网格背景
                    LineGraph(data: viewModel.gpuUsageData)
                        .stroke(Color.green, lineWidth: 2)
                        .frame(height: 200)
                }
                .background(Color.black.opacity(0.1))  // 也可以加上半透明背景颜色
                .cornerRadius(8)
            }

            VStack {
                Text(String(format: "Current Learning Rate: %.2f e-6", viewModel.currentMemoryUsage))
                    .font(.subheadline)
                    .foregroundColor(.blue)

                // 内存使用折线图
                ZStack {
                    GridBackground()  // 半透明网格背景
                    LineGraph(data: viewModel.memoryUsageData)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(height: 200)
                }
                .background(Color.black.opacity(0.1))  // 半透明背景
                .cornerRadius(8)
            }
        }
        .padding()
    }
}










//struct ButtonUsageView: View {
//    @StateObject private var viewModel = LossUsageViewModel()  // 使用 @StateObject 确保 viewModel 的唯一性
//
//    var body: some View {
//        
//    }
//}






















import SwiftUI

struct ContentView: View {
    @State var evaluator = LoRAEvaluator()
    @State var prompt = """
        table: 1-10015132-16
        columns: Player, No., Nationality, Position, Years in Toronto, School/Club Team
        Q: What is terrence ross' nationality
        A:
        """
    @State private var showText = false
    @State private var logOutput = "" // 用于显示的日志输出

    // 动态渐变的颜色数组
    @State private var gradientColors: [Color] = [Color.white, Color.mint.opacity(0.5), Color.blue.opacity(0.3), Color.green.opacity(0.4)]



    @State private var frameRate: Double = 0.0
    @State private var displayLink: CADisplayLink?
    @StateObject private var frameRateMonitor = FrameRateMonitor()
    @State private var currentModelTrainName: String = ""


    var body: some View {
        ZStack {
            // 动态的渐变背景，颜色会不断变化
            LinearGradient(gradient: Gradient(colors: gradientColors),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) // 动态渐变

            
             
        VStack {
            // TabView 用于滑动毛玻璃区域
            TabView {
                
                // 第一块毛玻璃视图
                BlurView()
                    .frame(width: 350, height: 550) // 调整毛玻璃的高度
                    .cornerRadius(20)
                    .overlay(
                        VStack(spacing: 10) {
                            GIFImage(name: "main_pic5")
                                .frame(height: 300)

                            // 第一段广告语，显示在GIF下方
                            Text("Revolutionizing Data Privacy for a Transparent and Secure Tomorrow")
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 15)
                                .foregroundColor(.black)

                            // 第二段广告语
                            LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .leading, endPoint: .trailing)
                                .mask(
                                    VStack {
                                        Text("Powered by Blockchain")
                                            .font(.headline)
                                            .multilineTextAlignment(.center)
                                        Text("and Federated Learning")
                                            .font(.headline)
                                            .multilineTextAlignment(.center)
                                    }
                                )
                                .frame(height: 80) // 设置文本的高度
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, -50) // 调整 top padding 以确保内容不被遮挡

                
                
                // 第二块毛玻璃视图（动态显示帧率信息）
                BlurView()
                    .frame(width: 350, height: 550)
                    .cornerRadius(20)
                    .overlay(
                        VStack(spacing: 10) {
 
                            GPUUsageView()
                        
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, -50)
                    .onAppear {
                        frameRateMonitor.startMonitoring()
                    }
                    .onDisappear {
                        frameRateMonitor.stopMonitoring()
                    }

                // 第三块毛玻璃视图
                BlurView()
                    .frame(width: 350,height: 550)
                    .cornerRadius(20)
                    .overlay(
                        VStack(spacing: 10) {
                            
                            LossUsageView()
 
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, -50)
                
                
                
                BlurView()
                    .frame(width: 350, height: 550)
                    .cornerRadius(20)
                    .overlay(
                        VStack(spacing: 20) {
                            VStack {
                                Button(action: {
                                    // 在此处处理按钮1的操作
                                }) {
                                    Text("Training Data")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(width: 150, height: 50)  // 控制按钮的宽度和高度
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                }
                                
                                // 按钮下方的附加信息
                                Text(evaluator.data_train_name)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack {
                                Button(action: {
                                    // 在此处处理按钮2的操作
                                }) {
                                    Text("Valid Data")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(width: 150, height: 50)  // 控制按钮的宽度和高度
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                }
                                
                                // 按钮下方的附加信息
                                Text(evaluator.data_valid_name)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            
                            
                            
                            
                            
                            VStack {
                                Button(action: {
                                    // 使用 Task 启动一个异步任务
                                    Task {
                                        // 在按钮点击时顺序选取下一个元素
                                        if let nextModelTrainName = evaluator.selectNextModelTrainName() {
                                            currentModelTrainName = nextModelTrainName  // 更新当前的 modelTrainName
                                            
                                            // 使用 MainActor.run 确保 modelConfiguration 在主线程上更新
                                            await MainActor.run {
                                                updateModelConfiguration(for: currentModelTrainName, evaluator: evaluator)
                                            }
                                        }
                                    }
                                }) {
                                    Text("Model Training")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(width: 150, height: 50)  // 控制按钮的宽度和高度
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                }
                                
                                // 按钮下方的附加信息
                                Text(currentModelTrainName.isEmpty ? "Select a model" : currentModelTrainName)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .onAppear {
                                // 初始化时显示第一个元素
                                if let firstModelTrainName = evaluator.selectNextModelTrainName() {
                                    currentModelTrainName = firstModelTrainName
                                }
                            }


                        
                            
                            
                            
                            
                            VStack {
                                Button(action: {
                                    // 在此处处理按钮4的操作
                                }) {
                                    Text("Stop Training")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(width: 150, height: 50)  // 控制按钮的宽度和高度
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                }
                                
                                // 按钮下方的附加信息
                                Text("Training has been stopped")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                    )
                    .padding(.horizontal)
                    .padding(.top, -50)

                
                
                
                
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always)) // 实现滑动效果和分页指示
            .frame(height: 650) // 设置滑动视图的高度

            Spacer()

            // 底部内容（进度条和日志输出）
            VStack {
                if let progress = evaluator.progress {
                    ProgressView(progress.title, value: progress.current ?? 0, total: progress.limit ?? 1)
                        .frame(maxWidth: .infinity, minHeight: 25)
                        .padding()
                }

                ScrollView {
                    ScrollViewReader { sp in
                        Text(evaluator.output + "\n" + logOutput)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .onChange(of: evaluator.output) { _, _ in
                                sp.scrollTo("bottom")
                            }
                            .onChange(of: logOutput) { _ in
                                sp.scrollTo("bottom")
                            }
                        Spacer()
                            .frame(width: 1, height: 1)
                            .id("bottom")
                    }
                }

                stateControlButtons()
            }
            .padding()
        }
        .onAppear {
            withAnimation {
                showText.toggle()
            }
            startDynamicGradientChange()
        }
    }
    }

    
    @MainActor
    func updateModelConfiguration(for modelName: String, evaluator: LoRAEvaluator) {
        switch modelName {
        case "smolLM_135M_4bit":
            evaluator.modelConfiguration = ModelConfiguration.smolLM_135M_4bit
        case "mistralNeMo4bit":
            evaluator.modelConfiguration = ModelConfiguration.mistralNeMo4bit
        case "mistral7B4bit":
            evaluator.modelConfiguration = ModelConfiguration.mistral7B4bit
        case "phi4bit":
            evaluator.modelConfiguration = ModelConfiguration.phi4bit
        case "phi3_5_4bit":
            evaluator.modelConfiguration = ModelConfiguration.phi3_5_4bit
        case "gemma2bQuantized":
            evaluator.modelConfiguration = ModelConfiguration.gemma2bQuantized
        case "gemma_2_9b_it_4bit":
            evaluator.modelConfiguration = ModelConfiguration.gemma_2_9b_it_4bit
        case "gemma_2_2b_it_4bit":
            evaluator.modelConfiguration = ModelConfiguration.gemma_2_2b_it_4bit
            
        default:
            print("Unknown model configuration")
        }
    }


 
    


    // 使用定时器定期更新渐变颜色，实现动态效果
    func startDynamicGradientChange() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 3)) {
                // 每次改变渐变颜色
                gradientColors = gradientColors.shuffled() // 随机打乱颜色顺序
            }
        }
    }





    @MainActor
    private func stateControlButtons() -> some View {
        Group { // 使用 Group 以确保返回相同的类型
            switch evaluator.state {
                
                
 
                
            case .idle:
                HStack {

                    Button(action: reset) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                    .disabled(evaluator.progress == nil)
                    
                    Spacer().frame(width: 80) // 使用固定宽度的 Spacer 来减少间距
                    
                    Button(action: start) {
                        Label("Start", systemImage: "play.fill")
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                    .disabled(evaluator.progress != nil)
                }



            case .training:
                EmptyView()

            case .evaluate:
                VStack {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 60)
                    Button("Evaluate", action: evaluate)
                }
                .disabled(evaluator.progress != nil)

            case .failed(let message):
                Text("Failed: \(message)")
                    .bold()
                    .foregroundColor(.red)
            }
        }
    }

    // 启动和评估的异步任务
    @MainActor // 确保这些方法在主线程执行
    func start() {
        Task {
            await evaluator.start()
        }
    }
    
    @MainActor
    private func reset() {
//        evaluator.reset() // 重置 evaluator 的状态
        prompt = "" // 清空输入的 prompt
        logOutput = "" // 清空日志输出
    }
    
    


    @MainActor // 确保这些方法在主线程执行
    func evaluate() {
        Task {
            await evaluator.evaluate(prompt: prompt)
        }
    }


    private func logAction(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        logOutput += "[\(timestamp)] \(message)\n"
    }

    struct BlurView: UIViewRepresentable {
        func makeUIView(context: Context) -> UIVisualEffectView {
            let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
            view.alpha = 0.7
            return view
        }

        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
    }
}












/// Progress reporting with a title.
struct Progress: Equatable, Sendable {
    let title: String
    let current: Double?
    let limit: Double?
}




 






// LoRAEvaluator 模型加载类
@Observable
@MainActor
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
    var data_train_name = "train"
    var data_valid_name = "valid"
    var modelTrainName = "smolLM_135M_4bit" /// phi4bit


//    private let modelConfiguration = ModelConfiguration.smolLM_135M_4bit
    internal var  modelConfiguration = ModelConfiguration.smolLM_135M_4bit
    private var model: ModelState = .idle

    private let loraLayers = 4
    private let learningRate: Float = 1e-5
    private let parameters = LoRATrain.Parameters(batchSize: 1, iterations: 200)

    private let generateParameters = GenerateParameters(temperature: 0.6, topP: 0.9)
    private let evaluateShowEvery = 8
    private let maxTokens = 200
    
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    var modelTrainNameList: [String] = [
            "smolLM_135M_4bit",
            "mistralNeMo4bit",
            "mistral7B4bit",
            "phi4bit",
            "phi3_5_4bit",
            "gemma2bQuantized",
            "gemma_2_9b_it_4bit",
            "gemma_2_2b_it_4bit"
        ]
        private var currentIndex = 0

        // 顺序选取列表中的元素并执行
        func selectNextModelTrainName() -> String? {
            guard !modelTrainNameList.isEmpty else { return nil }  // 如果列表为空，返回 nil
            let selectedModelTrainName = modelTrainNameList[currentIndex]
            currentIndex = (currentIndex + 1) % modelTrainNameList.count  // 循环递增索引
            return selectedModelTrainName
        }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   

    // 加载模型并显示进度
    func loadModel() async throws -> ModelContainer {
        switch self.model {
        case .idle:
            let name = modelConfiguration.name
            // 更新进度条的标题，显示加载状态
            await MainActor.run {
                progress = .init(title: "Loading \(name)", current: 0, limit: 1)
            }

            // 加载模型，并追踪下载进度
            let modelContainer = try await LLM.loadModelContainer(configuration: modelConfiguration) {
                progress in
                Task { @MainActor in
                    // 更新进度条的状态
                    self.progress = .init(
                        title: "Downloading \(name)",
                        current: progress.fractionCompleted,
                        limit: 1.0
                    )
                }
            }

            // 模型加载完成，更新状态
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
    
    nonisolated private func loraLayers(model: Module) -> LoRALinearLayers {
        guard let layerProvider = model as? LoRAModel else {
            Task {
                await MainActor.run {
                    fatalError(
                        "Model \(type(of: model)) (\(modelConfiguration.name)) must implement the LoRALayerProvider protocol"
                    )
                }
            }
            return []  // 需要返回一个空的值或者处理逻辑
        }

        return Array(layerProvider.loraLinearLayers().suffix(loraLayers))
    }


    private func startInner() async throws {
        // setup
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

//        let train = try loadLoRAData(name: "train")
//        let valid = try loadLoRAData(name: "valid")
        let train = try loadLoRAData(name: self.data_train_name)
        let valid = try loadLoRAData(name: self.data_valid_name)
        
        
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
        self.progress = .init(title: "Testing", current: nil, limit: nil)
        guard let test = try loadLoRAData(name: "test") else {
            state = .failed("Failed to load test data")
            return
        }

        let loss = await modelContainer.perform { model, tokenizer in
            LoRATrain.evaluate(
                model: model, dataset: test, tokenizer: tokenizer, batchSize: 1, batchCount: 0)
        }

        self.progress = nil
        self.output += "\n"
        self.output += "Test loss \(loss.formatted()), ppl \(exp(loss).formatted())\n"
        self.state = .evaluate
    }

    func evaluate(prompt: String) async {
        do {
            try await evaluateInner(prompt: prompt)
        } catch {
            self.state = .failed("Failed: \(error)")
        }
    }
    
    
    
    
    

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
    
    func evaluateInner(prompt: String) async throws {
        await MainActor.run {
            self.progress = .init(title: "Evaluating", current: nil, limit: nil)
            self.output = ""
        }

        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

        let modelContainer = try await loadModel()

        // 确保在主线程上访问 modelConfiguration
        let preparedPrompt = await MainActor.run {
            modelConfiguration.prepare(prompt: prompt)
        }

        let promptTokens = await modelContainer.perform { _, tokenizer in
            tokenizer.encode(text: preparedPrompt)
        }

        // 确保在主线程上访问 modelConfiguration.extraEOSTokens
        let result = await modelContainer.perform { model, tokenizer in
            LLM.generate(
                promptTokens: promptTokens, parameters: generateParameters, model: model,
                tokenizer: tokenizer,
                
                ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                extraEOSTokens: modelConfiguration.extraEOSTokens,
                ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                ///
                ///
                didGenerate: { tokens in
                    if tokens.count % evaluateShowEvery == 0 {
                        let fullOutput = tokenizer.decode(tokens: tokens)
                        Task { @MainActor in
                            self.output = fullOutput
                        }
                    }
                    return tokens.count >= maxTokens ? .stop : .more
                }
            )
        }


        await MainActor.run {
            self.output = result.output
            self.progress = nil
        }
    }



    
    
    
    
    
    
}
