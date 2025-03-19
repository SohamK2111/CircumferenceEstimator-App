
import SwiftUI
import Charts

struct ContentView: View {
    @StateObject var arModel = ARModel()
    
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
                // Live camera feed
                CameraView(arModel: arModel)
                    .edgesIgnoringSafeArea(.all)
                
                // Crosshair with red horizontal line and edge overlay dots
                GeometryReader { geometry in
                    let screenWidth = geometry.size.width
                    let screenHeight = geometry.size.height
                    let yPosition = screenHeight / 2
                    
                    ZStack {
                        // Draw red horizontal line
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yPosition))
                            path.addLine(to: CGPoint(x: screenWidth, y: yPosition))
                        }
                        .stroke(Color.red, lineWidth: 2)
                        .opacity(arModel.showEdgeOverlay && arModel.depthEdgeIndices.count > 0 ? 1 : 0)
                        .animation(.easeInOut(duration: 0.3), value: arModel.depthEdgeIndices)
                        
                        // If edge overlay is enabled, draw dots corresponding to detected edges.
                        if arModel.showEdgeOverlay,
                           let depthSlice = arModel.averagedCentralColumnsDepthFloats(colCount: 5) {
                            let n = depthSlice.count
                            let lowerBound = 0.19 * CGFloat(n - 1)
                            let upperBound = 0.81 * CGFloat(n - 1)
                            if arModel.showEdgeOverlay, let depthSlice = arModel.averagedCentralColumnsDepthFloats(colCount: 5) {
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
                                            .id("edge_black_\(edgeIndex)")  // Helps SwiftUI track changes

                                        Rectangle()
                                            .fill(Color.yellow)
                                            .frame(width: 2, height: 60)
                                            .position(x: x, y: yPosition)
                                            .id("edge_yellow_\(edgeIndex)")  // Helps SwiftUI track changes
                                    }
                                }
                                .animation(.easeInOut(duration: 0.3), value: arModel.depthEdgeIndices)
                            }
                        }
                    }
                }
                
                // Green plus at center
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
                
                // Temporary overlay messages
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
            .onAppear{
                arModel.resumeSession()
            }
            .onChange(of: isShowingMeasurements) { isActive in
                            if isActive {
                                arModel.pauseSession()
                            } else {
                                arModel.resumeSession()
                            }
                        }
            // Overlay: Measurements / Settings buttons + Depth UI
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
                    
//                    SpiritLevelBar(arModel: arModel)
//                        .padding(.horizontal, 10)
                    
                    // Show the depth map view only if enabled in settings.
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
                                // Start button
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
                                
                                // Combined Save button
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
}
    
    private func provideHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

// Updated SpiritLevelBar view.
struct SpiritLevelBar: View {
    @ObservedObject var arModel: ARModel

    var body: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width
            ZStack {
                // Background track for the level bar.
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 10)
                // The moving bubble indicator.
                Circle()
                    // Change bubble color: green if vertical, red otherwise.
                    .fill(arModel.isVertical ? Color.green : Color.red)
                    .frame(width: 20, height: 20)
                    .offset(x: bubbleOffset(for: barWidth))
                    .animation(.easeInOut, value: arModel.isVertical)
            }
        }
        .frame(height: 30)
    }
    
    // Maps the roll value (in radians) to a horizontal offset within the bar.
    func bubbleOffset(for width: CGFloat) -> CGFloat {
        let maxRoll: Double = 0.3  // Maximum roll (in radians) for clamping.
        let clampedRoll = max(min(arModel.roll, maxRoll), -maxRoll)
        let normalized = clampedRoll / maxRoll  // Normalized between -1 and 1.
        let maxOffset = (width - 20) / 2  // Leave room for the bubble.
        return CGFloat(normalized) * maxOffset
    }
}
