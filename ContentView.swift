//import SwiftUI
//import Charts
//
//// MARK: - App Phase Enum
//enum AppPhase {
//    case welcome
//    case calibration
//    case main
//}
//
//// MARK: - Main Container View
///// This container controls which phase is currently being displayed.
//struct MainContainerView: View {
//    @State private var phase: AppPhase = .welcome
//    @StateObject var arModel = ARModel()  // Shared ARModel for all phases
//
//    var body: some View {
//        switch phase {
//        case .welcome:
//            WelcomeView {
//                // Transition to calibration phase when the user taps "Skip" or completes the slides.
//                withAnimation {
//                    phase = .calibration
//                }
//            }
//        case .calibration:
//            CalibrationView(arModel: arModel) {
//                // After calibration (and variance computation), move to main measurement mode.
//                withAnimation {
//                    phase = .main
//                }
//            }
//        case .main:
//            MainMeasurementView(arModel: arModel)
//        }
//    }
//}
//
//// MARK: - Welcome View
///// A welcome screen featuring a soft blue gradient and multiple instructional slides.
//struct WelcomeView: View {
//    let onContinue: () -> Void
//
//    // Define your slides – feel free to split or change the text.
//    private let slides: [WelcomeSlide] = [
//        WelcomeSlide(
//            title: "Welcome!",
//            description: "This is a Virtual Measuring Tape which can be used to estimate lengths and circumferences."
//        ),
//        WelcomeSlide(
//            title: "Usage Directions",
//            description: "1. Hold the phone as steady as possible to minimise error."
//        ),
//        WelcomeSlide(
//            title: "Usage Directions",
//            description: "2. Ensure that the phone is vertical. When sufficient, the red indicator will turn green."
//        ),
//        WelcomeSlide(
//            title: "Usage Directions",
//            description: "3. Center the object to be measured in the frame. Ensure that there are no occluding objects between the camera and the object, and that the object isn't too close to walls."
//        ),
//        WelcomeSlide(
//            title: "Usage Directions",
//            description: "4. Use the horizontal red line as a ruler. For example, if measuring waists, align the red line with the thinnest part of the torso."
//        ),
//        WelcomeSlide(
//            title: "Usage Directions",
//            description: "5. Have the object rotate 360° or walk around it, saving measurements with the \"Save\" button."
//        ),
//        WelcomeSlide(
//            title: "Final Step",
//            description: "6. Go to the Measurements view and check that the measurements are reasonable. Then press Calculate!"
//        )
//    ]
//    
//    @State private var selectedTabIndex = 0
//
//    var body: some View {
//        ZStack {
//            // Soft blue gradient background.
//            LinearGradient(
//                gradient: Gradient(colors: [
//                    Color.blue.opacity(0.3),
//                    Color.blue.opacity(0.7)
//                ]),
//                startPoint: .top,
//                endPoint: .bottom
//            )
//            .edgesIgnoringSafeArea(.all)
//
//            VStack {
//                // TabView showing the slides as horizontal pages.
//                TabView(selection: $selectedTabIndex) {
//                    ForEach(0..<slides.count, id: \.self) { index in
//                        SlideView(slide: slides[index])
//                            .tag(index)
//                            .padding()
//                    }
//                }
//                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
//                .animation(.easeInOut, value: selectedTabIndex)
//                
//                // The Skip button at the bottom.
//                Button(action: {
//                    onContinue()
//                }) {
//                    Text("Skip")
//                        .font(.footnote)
//                        .padding(.vertical, 8)
//                        .padding(.horizontal, 16)
//                        .background(Color.white.opacity(0.7))
//                        .foregroundColor(.blue)
//                        .cornerRadius(8)
//                }
//                .padding(.bottom, 20)
//            }
//        }
//    }
//}
//
//// MARK: - Welcome Slide Model
//struct WelcomeSlide {
//    let title: String
//    let description: String
//}
//
//// MARK: - Slide View
//struct SlideView: View {
//    let slide: WelcomeSlide
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Text(slide.title)
//                .font(.largeTitle)
//                .fontWeight(.bold)
//                .foregroundColor(.white)
//            
//            Text(slide.description)
//                .foregroundColor(.white)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal, 20)
//        }
//    }
//}
//
//// MARK: - Calibration View
///// A calibration mode where the user sees the camera feed with calibration-specific UI.
///// In this version the detected edges and the horizontal red line are shown. A white circular ring is
///// displayed at the bottom that uses the same “save” logic as in the main app. When the user holds the ring for 3 seconds,
///// a Finish Calibration button appears. When tapped, the variance of the non-placeholder measurements (based on realWidth)
///// is computed and saved into arModel.variance before completing calibration.
//struct CalibrationView: View {
//    @ObservedObject var arModel: ARModel
//    let onCalibrationComplete: () -> Void
//    
//    // State variables for the long press gesture and finish button.
//    @State private var finishAvailable: Bool = false
//    @State private var saveTimer: Timer? = nil
//    @State private var hasFiredSaveTimer: Bool = false
//    @State private var pressStartTime: Date? = nil
//    @State private var showSaveFeedback: Bool = false
//
//    var body: some View {
//        ZStack {
//            // Camera view.
//            CameraView(arModel: arModel)
//                .edgesIgnoringSafeArea(.all)
//            
//            // Overlay for the red horizontal line and detected edges.
//            GeometryReader { geometry in
//                let screenWidth = geometry.size.width
//                let screenHeight = geometry.size.height
//                let yPosition = screenHeight / 2
//                ZStack {
//                    // Draw a red horizontal line.
//                    Path { path in
//                        path.move(to: CGPoint(x: 0, y: yPosition))
//                        path.addLine(to: CGPoint(x: screenWidth, y: yPosition))
//                    }
//                    .stroke(Color.red, lineWidth: 2)
//                    
//                    // Draw detected edge overlays if available.
//                    if arModel.showEdgeOverlay,
//                       let _ = arModel.averagedCentralColumnsDepthFloats(colCount: 5) {
//                        let n = arModel.averagedCentralColumnsDepthFloats(colCount: 5)!.count
//                        let lowerBound = 0.19 * CGFloat(n - 1)
//                        let upperBound = 0.81 * CGFloat(n - 1)
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            ForEach(arModel.depthEdgeIndices, id: \.self) { edgeIndex in
//                                let clampedIndex = min(max(CGFloat(edgeIndex), lowerBound), upperBound)
//                                let ratio = (clampedIndex - lowerBound) / (upperBound - lowerBound)
//                                let x = (1 - ratio) * screenWidth
//                                
//                                Rectangle()
//                                    .fill(Color.black.opacity(0.4))
//                                    .frame(width: 4, height: 62)
//                                    .position(x: x, y: yPosition)
//                                
//                                Rectangle()
//                                    .fill(Color.yellow)
//                                    .frame(width: 2, height: 60)
//                                    .position(x: x, y: yPosition)
//                            }
//                        }
//                    }
//                }
//            }
//            .edgesIgnoringSafeArea(.all)
//            
//            // Top overlay: a simple calibration label.
//            VStack {
//                Text("Calibration Mode")
//                    .font(.largeTitle)
//                    .foregroundColor(.white)
//                    .padding()
//                    
//                Spacer()
//            }
//            
//            // Bottom overlay: white circular button with long press gesture and, if held for 3 seconds, a Finish Calibration button appears.
//            VStack {
//                Spacer()
//                
//                // Feedback message indicating a measurement was recorded.
//                if showSaveFeedback {
//                    Text("Measurement Recorded!")
//                        .foregroundColor(.white)
//                        .padding(8)
//                        .background(Color.black.opacity(0.7))
//                        .cornerRadius(8)
//                        .padding(.bottom, 10)
//                }
//                
//                // White circular ring styled like a photo button.
//                ZStack {
//                    Circle()
//                        .stroke(Color.white, lineWidth: 4)
//                        .frame(width: 70, height: 70)
//                    Circle()
//                        .fill(Color.white.opacity(0.2))
//                        .frame(width: 70, height: 70)
//                }
//                // Long press gesture for saving measurements.
//                .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 10, pressing: { isPressing in
//                    if isPressing {
//                        pressStartTime = Date()
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                            if let start = pressStartTime, Date().timeIntervalSince(start) >= 0.5 {
//                                if saveTimer == nil {
//                                    provideHapticFeedback()
//                                    hasFiredSaveTimer = false
//                                    saveTimer = Timer.scheduledTimer(withTimeInterval: arModel.saveInterval, repeats: true) { _ in
//                                        provideHapticFeedback()
//                                        arModel.saveCurrentMeasurement()
//                                        showSaveFeedback = true
//                                        hasFiredSaveTimer = true
//                                    }
//                                }
//                            }
//                        }
//                    } else {
//                        if let start = pressStartTime, Date().timeIntervalSince(start) < 0.5 {
//                            provideHapticFeedback()
//                            arModel.saveCurrentMeasurement()
//                            showSaveFeedback = true
//                        }
//                        saveTimer?.invalidate()
//                        saveTimer = nil
//                        pressStartTime = nil
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                            withAnimation { showSaveFeedback = false }
//                        }
//                    }
//                }, perform: { })
//                // Simultaneous gesture that, if held for 3 seconds, makes the finish option available.
//                .simultaneousGesture(
//                    LongPressGesture(minimumDuration: 3.0)
//                        .onEnded { _ in
//                            finishAvailable = true
//                        }
//                )
//                .padding(.bottom, 20)
//                
//                // If the finish option is available, show the Finish Calibration button.
//                if finishAvailable {
//                    Button(action: {
//                        // Compute variance of the non-placeholder realWidth measurements.
//                        let validMeasurements = arModel.measurements.filter { !$0.isPlaceholder && $0.realWidth != nil }
//                        if validMeasurements.count > 1 {
//                            let widths = validMeasurements.compactMap { $0.realWidth }
//                            let mean = widths.reduce(0, +) / Double(widths.count)
//                            let sumSq = widths.map { pow($0 - mean, 2) }.reduce(0, +)
//                            let variance = sumSq / Double(widths.count - 1)
//                            arModel.variance = variance * 10000
//                            arModel.measurements.removeAll()
//                        } else {
//                            arModel.variance = 0
//                            arModel.measurements.removeAll()
//                        }
//                        // Complete calibration.
//                        onCalibrationComplete()
//                    }) {
//                        Text("Finish Calibration")
//                            .font(.headline)
//                            .padding()
//                            .background(Color.green)
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//                    .padding(.bottom, 40)
//                }
//            }
//        }
//    }
//    
//    // MARK: - Haptic Feedback Helper for CalibrationView
//    private func provideHapticFeedback() {
//        let generator = UIImpactFeedbackGenerator(style: .medium)
//        generator.impactOccurred()
//    }
//}
//
//// MARK: - Main Measurement View
///// This view contains your existing measurement functionality exactly as before.
//struct MainMeasurementView: View {
//    @ObservedObject var arModel: ARModel
//
//    // Temporary feedback flags.
//    @State private var showStartFeedback: Bool = false
//    @State private var showSaveFeedback: Bool = false
//    
//    // Timer and flags for combined save approach.
//    @State private var saveTimer: Timer? = nil
//    @State private var hasFiredSaveTimer: Bool = false
//    @State private var pressStartTime: Date? = nil
//    
//    @State private var isShowingMeasurements = false
//    
//    var body: some View {
//        NavigationView {
//            ZStack(alignment: .center) {
//                // Live camera feed.
//                CameraView(arModel: arModel)
//                    .edgesIgnoringSafeArea(.all)
//                
//                // Crosshair with red horizontal line and edge overlay dots.
//                GeometryReader { geometry in
//                    let screenWidth = geometry.size.width
//                    let screenHeight = geometry.size.height
//                    let yPosition = screenHeight / 2
//                    
//                    ZStack {
//                        // Draw red horizontal line.
//                        Path { path in
//                            path.move(to: CGPoint(x: 0, y: yPosition))
//                            path.addLine(to: CGPoint(x: screenWidth, y: yPosition))
//                        }
//                        .stroke(Color.red, lineWidth: 2)
//                        .opacity(arModel.showEdgeOverlay && arModel.depthEdgeIndices.count > 0 ? 1 : 0)
//                        .animation(.easeInOut(duration: 0.3), value: arModel.depthEdgeIndices)
//                        
//                        // Draw edge overlay dots if enabled.
//                        if arModel.showEdgeOverlay,
//                           let depthSlice = arModel.averagedCentralColumnsDepthFloats(colCount: 5) {
//                            let n = depthSlice.count
//                            let lowerBound = 0.19 * CGFloat(n - 1)
//                            let upperBound = 0.81 * CGFloat(n - 1)
//                            withAnimation(.easeInOut(duration: 0.3)) {
//                                ForEach(arModel.depthEdgeIndices, id: \.self) { edgeIndex in
//                                    let clampedIndex = min(max(CGFloat(edgeIndex), lowerBound), upperBound)
//                                    let ratio = (clampedIndex - lowerBound) / (upperBound - lowerBound)
//                                    let x = (1 - ratio) * screenWidth
//
//                                    Rectangle()
//                                        .fill(Color.black.opacity(0.4))
//                                        .frame(width: 4, height: 62)
//                                        .position(x: x, y: yPosition)
//                                        .id("edge_black_\(edgeIndex)")
//
//                                    Rectangle()
//                                        .fill(Color.yellow)
//                                        .frame(width: 2, height: 60)
//                                        .position(x: x, y: yPosition)
//                                        .id("edge_yellow_\(edgeIndex)")
//                                }
//                            }
//                            .animation(.easeInOut(duration: 0.3), value: arModel.depthEdgeIndices)
//                        }
//                    }
//                }
//                
//                // Green plus at the center.
//                ZStack {
//                    Rectangle()
//                        .fill(Color.black.opacity(0.3))
//                        .frame(width: 4, height: 22)
//                    Rectangle()
//                        .fill(Color.black.opacity(0.3))
//                        .frame(width: 22, height: 4)
//                    Rectangle()
//                        .fill(Color.green)
//                        .frame(width: 2, height: 20)
//                    Rectangle()
//                        .fill(Color.green)
//                        .frame(width: 20, height: 2)
//                }
//                
//                // Temporary overlay messages.
//                VStack {
//                    if showStartFeedback {
//                        Text("Start Pressed!")
//                            .foregroundColor(.white)
//                            .padding(10)
//                            .background(Color.blue.opacity(0.8))
//                            .cornerRadius(8)
//                            .transition(.opacity.combined(with: .scale))
//                    }
//                    
//                    if showSaveFeedback {
//                        Text("Measurement Saved!")
//                            .foregroundColor(.white)
//                            .padding(10)
//                            .background(Color.green.opacity(0.8))
//                            .cornerRadius(8)
//                            .transition(.opacity.combined(with: .scale))
//                    }
//                }
//                .animation(.easeInOut(duration: 0.3), value: showStartFeedback || showSaveFeedback)
//                .padding(.top, 100)
//            }
//            .navigationBarHidden(true)
//            .onAppear {
//                arModel.resumeSession()
//            }
//            .onChange(of: isShowingMeasurements) { isActive in
//                if isActive {
//                    arModel.pauseSession()
//                } else {
//                    arModel.resumeSession()
//                }
//            }
//            // Overlay: Measurements / Settings buttons + Depth UI.
//            .overlay(
//                VStack(spacing: 10) {
//                    HStack {
//                        NavigationLink(destination: MeasurementsView(arModel: arModel), isActive: $isShowingMeasurements) {
//                            Text("Measurements")
//                                .font(.headline)
//                                .foregroundColor(.white)
//                                .padding(10)
//                                .background(Color.black.opacity(0.5))
//                                .cornerRadius(10)
//                        }
//                        Spacer()
//                        NavigationLink(destination: SettingsView(arModel: arModel)) {
//                            Image(systemName: "gear")
//                                .font(.title)
//                                .foregroundColor(.white)
//                                .padding(10)
//                                .background(Color.black.opacity(0.5))
//                                .clipShape(Circle())
//                        }
//                    }
//                    .padding([.top, .horizontal], 20)
//                    
//                    Spacer()
//                    
//                    // Depth map view.
//                    if arModel.showDepthMapView {
//                        if let slice = arModel.averagedCentralColumnsDepthFloats(colCount: 5) {
//                            DepthMapView(depthData: slice,
//                                         depthEdges: arModel.depthEdgeIndices,
//                                         usedDepthEdges: arModel.usedDepthEdgeIndices)
//                            .background(Color.black.opacity(0.7))
//                            .cornerRadius(10)
//                            .frame(height: 200)
//                            .padding(.horizontal, 10)
//                            .padding(.bottom, -5)
//                        }
//                    }
//                    if let slice = arModel.averagedCentralColumnsDepthFloats(colCount: 5) {
//                        HStack(spacing: 15) {
//                            VStack(spacing: 15) {
//                                // Start button.
//                                Button(action: {
//                                    provideHapticFeedback()
//                                    arModel.resetInitialYaw()
//                                    showStartFeedback = true
//                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                                        withAnimation { showStartFeedback = false }
//                                    }
//                                }) {
//                                    Text("Start")
//                                        .frame(maxWidth: .infinity)
//                                }
//                                .font(.subheadline)
//                                .foregroundColor(.white)
//                                .padding(10)
//                                .background(Color.blue)
//                                .cornerRadius(10)
//                                
//                                // Combined Save button.
//                                Button(action: { }) {
//                                    Text("Save")
//                                        .frame(maxWidth: .infinity)
//                                }
//                                .font(.subheadline)
//                                .foregroundColor(.white)
//                                .padding(10)
//                                .background(Color.green)
//                                .cornerRadius(10)
//                                .onLongPressGesture(
//                                    minimumDuration: 0.5,
//                                    maximumDistance: 10,
//                                    pressing: { isPressing in
//                                        if isPressing {
//                                            pressStartTime = Date()
//                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                                                if let start = pressStartTime, Date().timeIntervalSince(start) >= 0.5 {
//                                                    if saveTimer == nil {
//                                                        provideHapticFeedback()
//                                                        hasFiredSaveTimer = false
//                                                        saveTimer = Timer.scheduledTimer(withTimeInterval: arModel.saveInterval, repeats: true) { _ in
//                                                            provideHapticFeedback()
//                                                            arModel.saveCurrentMeasurement()
//                                                            showSaveFeedback = true
//                                                            hasFiredSaveTimer = true
//                                                        }
//                                                    }
//                                                }
//                                            }
//                                        } else {
//                                            if let start = pressStartTime, Date().timeIntervalSince(start) < 0.5 {
//                                                provideHapticFeedback()
//                                                arModel.saveCurrentMeasurement()
//                                                showSaveFeedback = true
//                                            }
//                                            saveTimer?.invalidate()
//                                            saveTimer = nil
//                                            pressStartTime = nil
//                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                                                withAnimation { showSaveFeedback = false }
//                                            }
//                                        }
//                                    },
//                                    perform: { }
//                                )
//                            }
//                            .frame(minWidth: 0, maxWidth: 130)
//                            
//                            VStack(spacing: 6) {
//                                if let usedDepth = arModel.screenPixelSpanFromEdges {
//                                    Text(String(format: "Pixels: %.2f", usedDepth))
//                                        .foregroundColor(.white)
//                                } else {
//                                    Text("Pixels: --")
//                                        .foregroundColor(.white)
//                                }
//                                
//                                if let centralDepth = arModel.centralDepth {
//                                    Text(String(format: "Central Depth: %.2f m", centralDepth))
//                                        .foregroundColor(.white)
//                                    if centralDepth <= 0.25 {
//                                        Text("Please stand further back!")
//                                            .foregroundColor(.yellow)
//                                            .font(.caption)
//                                    }
//                                } else {
//                                    Text("Central Depth: -- m")
//                                        .foregroundColor(.white)
//                                }
//                                
//                                if let rw = arModel.realWidth {
//                                    Text(String(format: "Real Width: %.1f cm", rw * 100))
//                                        .foregroundColor(.white)
//                                } else {
//                                    Text("Real Width: -- cm")
//                                        .foregroundColor(.white)
//                                }
//                                
//                                Text(String(format: "Rotation Angle: %.1f°", arModel.rotationAngle))
//                                    .foregroundColor(.white)
//                            }
//                            .frame(minWidth: 0, maxWidth: 300)
//                        }
//                        .padding(10)
//                        .background(Color.black.opacity(0.7))
//                        .cornerRadius(10)
//                        .padding(.horizontal, 10)
//                        .padding(.bottom, 15)
//                    }
//                }
//                , alignment: .top
//            )
//        }
//        .navigationViewStyle(StackNavigationViewStyle())
//    }
//    
//    // MARK: - Haptic Feedback Helper for MainMeasurementView
//    private func provideHapticFeedback() {
//        let generator = UIImpactFeedbackGenerator(style: .medium)
//        generator.impactOccurred()
//    }
//}
//
//// MARK: - SpiritLevelBar (Optional)
//// Your existing SpiritLevelBar view, if needed.
//struct SpiritLevelBar: View {
//    @ObservedObject var arModel: ARModel
//
//    var body: some View {
//        GeometryReader { geometry in
//            let barWidth = geometry.size.width
//            ZStack {
//                Capsule()
//                    .fill(Color.gray.opacity(0.3))
//                    .frame(height: 10)
//                Circle()
//                    .fill(arModel.isVertical ? Color.green : Color.red)
//                    .frame(width: 20, height: 20)
//                    .offset(x: bubbleOffset(for: barWidth))
//                    .animation(.easeInOut, value: arModel.isVertical)
//            }
//        }
//        .frame(height: 30)
//    }
//    
//    func bubbleOffset(for width: CGFloat) -> CGFloat {
//        let maxRoll: Double = 0.3  // Maximum roll (in radians) for clamping.
//        let clampedRoll = max(min(arModel.roll, maxRoll), -maxRoll)
//        let normalized = clampedRoll / maxRoll  // Normalized between -1 and 1.
//        let maxOffset = (width - 20) / 2  // Leave room for the bubble.
//        return CGFloat(normalized) * maxOffset
//    }
//}


import SwiftUI
import Charts

// MARK: - App Phase Enum
enum AppPhase {
    case welcome
    case calibration
    case main
}

// MARK: - Main Container View
/// This container controls which phase is currently being displayed.
struct MainContainerView: View {
    @State private var phase: AppPhase = .welcome
    @StateObject var arModel = ARModel()  // Shared ARModel for all phases

    var body: some View {
        switch phase {
        case .welcome:
            WelcomeView {
                // Transition to calibration phase when the user taps "Skip" or completes the slides.
                withAnimation {
                    phase = .calibration
                }
            }
        case .calibration:
            CalibrationView(arModel: arModel) {
                // After calibration (and variance computation), move to main measurement mode.
                withAnimation {
                    phase = .main
                }
            }
        case .main:
            MainMeasurementView(arModel: arModel)
        }
    }
}

// MARK: - Welcome View
/// A welcome screen featuring a soft blue gradient and multiple instructional slides.
struct WelcomeView: View {
    let onContinue: () -> Void

    // Define your slides – feel free to split or change the text.
    private let slides: [WelcomeSlide] = [
        WelcomeSlide(
            title: "Welcome!",
            description: "This is a Virtual Measuring Tape which can be used to estimate lengths and circumferences."
        ),
        WelcomeSlide(
            title: "Usage Directions",
            description: "1. Hold the phone as steady as possible to minimise error."
        ),
        WelcomeSlide(
            title: "Usage Directions",
            description: "2. Ensure that the phone is vertical. When sufficient, the red indicator will turn green."
        ),
        WelcomeSlide(
            title: "Usage Directions",
            description: "3. Center the object to be measured in the frame. Ensure that there are no occluding objects between the camera and the object, and that the object isn't too close to walls."
        ),
        WelcomeSlide(
            title: "Usage Directions",
            description: "4. Use the horizontal red line as a ruler. For example, if measuring waists, align the red line with the thinnest part of the torso."
        ),
        WelcomeSlide(
            title: "Usage Directions",
            description: "5. Have the object rotate 360° or walk around it, saving measurements with the \"Save\" button."
        ),
        WelcomeSlide(
            title: "Final Step",
            description: "6. Go to the Measurements view and check that the measurements are reasonable. Then press Calculate!"
        )
    ]
    
    @State private var selectedTabIndex = 0

    var body: some View {
        ZStack {
            // Soft blue gradient background.
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.3),
                    Color.blue.opacity(0.7)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack {
                // TabView showing the slides as horizontal pages.
                TabView(selection: $selectedTabIndex) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        SlideView(slide: slides[index])
                            .tag(index)
                            .padding()
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .animation(.easeInOut, value: selectedTabIndex)
                
                // The Skip button at the bottom.
                Button(action: {
                    onContinue()
                }) {
                    Text("Skip")
                        .font(.footnote)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.7))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Welcome Slide Model
struct WelcomeSlide {
    let title: String
    let description: String
}

// MARK: - Slide View
struct SlideView: View {
    let slide: WelcomeSlide

    var body: some View {
        VStack(spacing: 20) {
            Text(slide.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(slide.description)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }
}

// MARK: - Calibration View
/// A calibration mode where the user sees the camera feed with calibration-specific UI.
/// In this version the detected edges and the horizontal red line are shown. A white circular ring is
/// displayed at the bottom that uses the same “save” logic as in the main app. When the user holds the ring for 3 seconds,
/// a Finish Calibration button appears. When tapped, the variance of the non-placeholder measurements (based on realWidth)
/// is computed, converted to cm², and its standard deviation is derived. If the standard deviation exceeds 2 cm,
/// an alert is shown, the measurements are reset, and calibration starts over.
struct CalibrationView: View {
    @ObservedObject var arModel: ARModel
    let onCalibrationComplete: () -> Void
    
    // State variables for the long press gesture and finish button.
    @State private var finishAvailable: Bool = false
    @State private var saveTimer: Timer? = nil
    @State private var hasFiredSaveTimer: Bool = false
    @State private var pressStartTime: Date? = nil
    @State private var showSaveFeedback: Bool = false
    
    // State for showing calibration error alert.
    @State private var showCalibrationErrorAlert: Bool = false

    var body: some View {
        ZStack {
            // Camera view.
            CameraView(arModel: arModel)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay for the red horizontal line and detected edges.
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let screenHeight = geometry.size.height
                let yPosition = screenHeight / 2
                ZStack {
                    // Draw a red horizontal line.
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: yPosition))
                        path.addLine(to: CGPoint(x: screenWidth, y: yPosition))
                    }
                    .stroke(Color.red, lineWidth: 2)
                    
                    // Draw detected edge overlays if available.
                    if arModel.showEdgeOverlay,
                       let _ = arModel.averagedCentralColumnsDepthFloats(colCount: 5) {
                        let n = arModel.averagedCentralColumnsDepthFloats(colCount: 5)!.count
                        let lowerBound = 0.19 * CGFloat(n - 1)
                        let upperBound = 0.81 * CGFloat(n - 1)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            ForEach(arModel.depthEdgeIndices, id: \.self) { edgeIndex in
                                let clampedIndex = min(max(CGFloat(edgeIndex), lowerBound), upperBound)
                                let ratio = (clampedIndex - lowerBound) / (upperBound - lowerBound)
                                let x = (1 - ratio) * screenWidth
                                
                                Rectangle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 4, height: 62)
                                    .position(x: x, y: yPosition)
                                
                                Rectangle()
                                    .fill(Color.yellow)
                                    .frame(width: 2, height: 60)
                                    .position(x: x, y: yPosition)
                            }
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            // Top overlay: a simple calibration label.
            VStack {
                Text("Calibration Mode")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
                    
                Spacer()
            }
            
            // Bottom overlay: white circular button with long press gesture and, if held for 3 seconds, a Finish Calibration button appears.
            VStack {
                Spacer()
                
                // Feedback message indicating a measurement was recorded.
                if showSaveFeedback {
                    Text("Measurement Recorded!")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.bottom, 10)
                }
                
                // White circular ring styled like a photo button.
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 70, height: 70)
                }
                // Long press gesture for saving measurements.
                .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 10, pressing: { isPressing in
                    if isPressing {
                        pressStartTime = Date()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if let start = pressStartTime, Date().timeIntervalSince(start) >= 0.5 {
                                if saveTimer == nil {
                                    provideHapticFeedback()
                                    hasFiredSaveTimer = false
                                    saveTimer = Timer.scheduledTimer(withTimeInterval: arModel.saveInterval, repeats: true) { _ in
                                        provideHapticFeedback()
                                        arModel.saveCurrentMeasurement()
                                        showSaveFeedback = true
                                        hasFiredSaveTimer = true
                                    }
                                }
                            }
                        }
                    } else {
                        if let start = pressStartTime, Date().timeIntervalSince(start) < 0.5 {
                            provideHapticFeedback()
                            arModel.saveCurrentMeasurement()
                            showSaveFeedback = true
                        }
                        saveTimer?.invalidate()
                        saveTimer = nil
                        pressStartTime = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation { showSaveFeedback = false }
                        }
                    }
                }, perform: { })
                // Simultaneous gesture that, if held for 3 seconds, makes the finish option available.
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 3.0)
                        .onEnded { _ in
                            finishAvailable = true
                        }
                )
                .padding(.bottom, 20)
                
                // If the finish option is available, show the Finish Calibration button.
                if finishAvailable {
                    Button(action: {
                        // Compute variance of the non-placeholder realWidth measurements.
                        let validMeasurements = arModel.measurements.filter { !$0.isPlaceholder && $0.realWidth != nil }
                        if validMeasurements.count > 1 {
                            let widths = validMeasurements.compactMap { $0.realWidth }
                            let mean = widths.reduce(0, +) / Double(widths.count)
                            let sumSq = widths.map { pow($0 - mean, 2) }.reduce(0, +)
                            let variance = sumSq / Double(widths.count - 1)
                            let varianceCm2 = variance * 10000.0  // variance in cm²
                            let stdDevCm = sqrt(varianceCm2)
                            
                            // If the standard deviation exceeds 2 cm, show an alert and reset calibration.
                            if stdDevCm > 1.5 {
                                showCalibrationErrorAlert = true
                                arModel.measurements.removeAll()
                                return
                            } else {
                                arModel.variance = varianceCm2
                                arModel.measurements.removeAll()
                            }
                        } else {
                            arModel.variance = 0
                            arModel.measurements.removeAll()
                        }
                        // Complete calibration.
                        onCalibrationComplete()
                    }) {
                        Text("Finish Calibration")
                            .font(.headline)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .alert(isPresented: $showCalibrationErrorAlert) {
            Alert(
                title: Text("Calibration Error"),
                message: Text("Too much noise detected during calibration. Please try calibrating again in a different environment or try again."),
                dismissButton: .default(Text("Try Again"), action: {
                    // Reset finish state to allow a fresh calibration.
                    finishAvailable = false
                })
            )
        }
    }
    
    // MARK: - Haptic Feedback Helper for CalibrationView
    private func provideHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Main Measurement View
/// This view contains your existing measurement functionality exactly as before.
struct MainMeasurementView: View {
    @ObservedObject var arModel: ARModel

    // Temporary feedback flags.
    @State private var showStartFeedback: Bool = false
    @State private var showSaveFeedback: Bool = false
    
    // Timer and flags for combined save approach.
    @State private var saveTimer: Timer? = nil
    @State private var hasFiredSaveTimer: Bool = false
    @State private var pressStartTime: Date? = nil
    
    @State private var isShowingMeasurements = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .center) {
                // Live camera feed.
                CameraView(arModel: arModel)
                    .edgesIgnoringSafeArea(.all)
                
                // Crosshair with red horizontal line and edge overlay dots.
                GeometryReader { geometry in
                    let screenWidth = geometry.size.width
                    let screenHeight = geometry.size.height
                    let yPosition = screenHeight / 2
                    
                    ZStack {
                        // Draw red horizontal line.
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yPosition))
                            path.addLine(to: CGPoint(x: screenWidth, y: yPosition))
                        }
                        .stroke(Color.red, lineWidth: 2)
                        .opacity(arModel.showEdgeOverlay && arModel.depthEdgeIndices.count > 0 ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: arModel.depthEdgeIndices)
                        
                        // Draw edge overlay dots if enabled.
                        if arModel.showEdgeOverlay,
                           let depthSlice = arModel.averagedCentralColumnsDepthFloats(colCount: 5) {
                            let n = depthSlice.count
                            let lowerBound = 0.19 * CGFloat(n - 1)
                            let upperBound = 0.81 * CGFloat(n - 1)
                            withAnimation(.easeInOut(duration: 0.3)) {
                                ForEach(arModel.depthEdgeIndices, id: \.self) { edgeIndex in
                                    let clampedIndex = min(max(CGFloat(edgeIndex), lowerBound), upperBound)
                                    let ratio = (clampedIndex - lowerBound) / (upperBound - lowerBound)
                                    let x = (1 - ratio) * screenWidth

                                    Rectangle()
                                        .fill(Color.black.opacity(0.4))
                                        .frame(width: 4, height: 62)
                                        .position(x: x, y: yPosition)
                                        .id("edge_black_\(edgeIndex)")

                                    Rectangle()
                                        .fill(Color.yellow)
                                        .frame(width: 2, height: 60)
                                        .position(x: x, y: yPosition)
                                        .id("edge_yellow_\(edgeIndex)")
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: arModel.depthEdgeIndices)
                        }
                    }
                }
                
                // Green plus at the center.
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 4, height: 22)
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 22, height: 4)
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 2, height: 20)
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 20, height: 2)
                }
                
                // Temporary overlay messages.
                VStack {
                    if showStartFeedback {
                        Text("Start Pressed!")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(8)
                            .transition(.opacity.combined(with: .scale))
                    }
                    
                    if showSaveFeedback {
                        Text("Measurement Saved!")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(8)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: showStartFeedback || showSaveFeedback)
                .padding(.top, 100)
            }
            .navigationBarHidden(true)
            .onAppear {
                arModel.resumeSession()
            }
            .onChange(of: isShowingMeasurements) { isActive in
                if isActive {
                    arModel.pauseSession()
                } else {
                    arModel.resumeSession()
                }
            }
            // Overlay: Measurements / Settings buttons + Depth UI.
            .overlay(
                VStack(spacing: 10) {
                    HStack {
                        NavigationLink(destination: MeasurementsView(arModel: arModel), isActive: $isShowingMeasurements) {
                            Text("Measurements")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(10)
                        }
                        Spacer()
                        NavigationLink(destination: SettingsView(arModel: arModel)) {
                            Image(systemName: "gear")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding([.top, .horizontal], 20)
                    
                    Spacer()
                    
                    // Depth map view.
                    if arModel.showDepthMapView {
                        if let slice = arModel.averagedCentralColumnsDepthFloats(colCount: 5) {
                            DepthMapView(depthData: slice,
                                         depthEdges: arModel.depthEdgeIndices,
                                         usedDepthEdges: arModel.usedDepthEdgeIndices)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .frame(height: 200)
                            .padding(.horizontal, 10)
                            .padding(.bottom, -5)
                        }
                    }
                    if let slice = arModel.averagedCentralColumnsDepthFloats(colCount: 5) {
                        HStack(spacing: 15) {
                            VStack(spacing: 15) {
                                // Start button.
                                Button(action: {
                                    provideHapticFeedback()
                                    arModel.resetInitialYaw()
                                    showStartFeedback = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        withAnimation { showStartFeedback = false }
                                    }
                                }) {
                                    Text("Start")
                                        .frame(maxWidth: .infinity)
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.blue)
                                .cornerRadius(10)
                                
                                // Combined Save button.
                                Button(action: { }) {
                                    Text("Save")
                                        .frame(maxWidth: .infinity)
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.green)
                                .cornerRadius(10)
                                .onLongPressGesture(
                                    minimumDuration: 0.5,
                                    maximumDistance: 10,
                                    pressing: { isPressing in
                                        if isPressing {
                                            pressStartTime = Date()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                if let start = pressStartTime, Date().timeIntervalSince(start) >= 0.5 {
                                                    if saveTimer == nil {
                                                        provideHapticFeedback()
                                                        hasFiredSaveTimer = false
                                                        saveTimer = Timer.scheduledTimer(withTimeInterval: arModel.saveInterval, repeats: true) { _ in
                                                            provideHapticFeedback()
                                                            arModel.saveCurrentMeasurement()
                                                            showSaveFeedback = true
                                                            hasFiredSaveTimer = true
                                                        }
                                                    }
                                                }
                                            }
                                        } else {
                                            if let start = pressStartTime, Date().timeIntervalSince(start) < 0.5 {
                                                provideHapticFeedback()
                                                arModel.saveCurrentMeasurement()
                                                showSaveFeedback = true
                                            }
                                            saveTimer?.invalidate()
                                            saveTimer = nil
                                            pressStartTime = nil
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                withAnimation { showSaveFeedback = false }
                                            }
                                        }
                                    },
                                    perform: { }
                                )
                            }
                            .frame(minWidth: 0, maxWidth: 130)
                            
                            VStack(spacing: 6) {
                                if let usedDepth = arModel.screenPixelSpanFromEdges {
                                    Text(String(format: "Pixels: %.2f", usedDepth))
                                        .foregroundColor(.white)
                                } else {
                                    Text("Pixels: --")
                                        .foregroundColor(.white)
                                }
                                
                                if let centralDepth = arModel.centralDepth {
                                    Text(String(format: "Central Depth: %.2f m", centralDepth))
                                        .foregroundColor(.white)
                                    if centralDepth <= 0.25 {
                                        Text("Please stand further back!")
                                            .foregroundColor(.yellow)
                                            .font(.caption)
                                    }
                                } else {
                                    Text("Central Depth: -- m")
                                        .foregroundColor(.white)
                                }
                                
                                if let rw = arModel.realWidth {
                                    Text(String(format: "Real Width: %.1f cm", rw * 100))
                                        .foregroundColor(.white)
                                } else {
                                    Text("Real Width: -- cm")
                                        .foregroundColor(.white)
                                }
                                
                                Text(String(format: "Rotation Angle: %.1f°", arModel.rotationAngle))
                                    .foregroundColor(.white)
                            }
                            .frame(minWidth: 0, maxWidth: 300)
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 15)
                    }
                }
                , alignment: .top
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Haptic Feedback Helper for MainMeasurementView
    private func provideHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - SpiritLevelBar (Optional)
// Your existing SpiritLevelBar view, if needed.
struct SpiritLevelBar: View {
    @ObservedObject var arModel: ARModel

    var body: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width
            ZStack {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 10)
                Circle()
                    .fill(arModel.isVertical ? Color.green : Color.red)
                    .frame(width: 20, height: 20)
                    .offset(x: bubbleOffset(for: barWidth))
                    .animation(.easeInOut, value: arModel.isVertical)
            }
        }
        .frame(height: 30)
    }
    
    func bubbleOffset(for width: CGFloat) -> CGFloat {
        let maxRoll: Double = 0.3  // Maximum roll (in radians) for clamping.
        let clampedRoll = max(min(arModel.roll, maxRoll), -maxRoll)
        let normalized = clampedRoll / maxRoll  // Normalized between -1 and 1.
        let maxOffset = (width - 20) / 2  // Leave room for the bubble.
        return CGFloat(normalized) * maxOffset
    }
}
