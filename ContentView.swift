//import SwiftUI
//
//struct ContentView: View {
//    @StateObject var arModel = ARModel()
//    
//    // States for temporary feedback
//    @State private var showStartFeedback: Bool = false
//    @State private var showSaveFeedback: Bool = false
//    
//    var body: some View {
//        NavigationView {
//            ZStack(alignment: .center) {
//                
//                // 1) Live camera feed
//                CameraView(arModel: arModel)
//                    .edgesIgnoringSafeArea(.all)
//                
//                // 2) Optional crosshair line
//                GeometryReader { geometry in
//                    let screenWidth = geometry.size.width
//                    let screenHeight = geometry.size.height
//                    let yPosition = screenHeight / 2
//                    
//                    Path { path in
//                        path.move(to: CGPoint(x: 0, y: yPosition))
//                        path.addLine(to: CGPoint(x: screenWidth, y: yPosition))
//                    }
//                    .stroke(Color.red, lineWidth: 2)
//                }
//                .frame(width: UIScreen.main.bounds.width,
//                       height: UIScreen.main.bounds.height)
//                
//                // 3) Green plus at center
//                ZStack {
//                    Rectangle()
//                        .fill(Color.green)
//                        .frame(width: 2, height: 20)
//                    Rectangle()
//                        .fill(Color.green)
//                        .frame(width: 20, height: 2)
//                }
//                
//                // 4) Temporary overlay messages for button presses
//                VStack {
//                    // If "Start" button was pressed
//                    if showStartFeedback {
//                        Text("Start Pressed!")
//                            .foregroundColor(.white)
//                            .padding(10)
//                            .background(Color.blue.opacity(0.8))
//                            .cornerRadius(8)
//                            // A little transition effect
//                            .transition(.opacity.combined(with: .scale))
//                    }
//                    
//                    // If "Save" button was pressed
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
//                .padding(.top, 100) // position near top, adjust as needed
//            }
//            .navigationBarHidden(true)
//            
//            // 5) Overlay (Measurements button + Depth + Stats)
//            .overlay(
//                VStack(spacing: 10) {
//                    
//                    // "Measurements" button (moved 30 px down from top -> total ~70)
//                    NavigationLink(destination: MeasurementsView(arModel: arModel)) {
//                        Text("Measurements")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                            .padding(10)
//                            .background(Color.orange)
//                            .cornerRadius(10)
//                    }
//                    .padding(.top, 70)
//                    
//                    Spacer()
//                    
//                    // Only show depth UI if we have valid LiDAR data
//                    if let slice = arModel.averagedCentralColumnsDepthFloats(colCount: 5) {
//                        
//                        // DepthMapView (moved up 20 px by reducing bottom padding)
//                        DepthMapView(depthData: slice, depthEdges: arModel.depthEdgeIndices)
//                            .background(Color.black.opacity(0.7))
//                            .cornerRadius(10)
//                            .frame(height: 200)
//                            .padding(.horizontal, 10)
//                            .padding(.bottom, -5)
//                        
//                        // A single background to hold:
//                        // (a) Start & Save buttons
//                        // (b) Stat info (pixel count, depth, real width, angle)
//                        HStack(spacing: 15) {
//                            
//                            // Left column: Start + Save
//                            VStack(spacing: 15) {
//                                Button("Start") {
//                                    provideHapticFeedback()
//                                    
//                                    // ARModel action
//                                    arModel.resetInitialYaw()
//                                    
//                                    // Show ephemeral message
//                                    showStartFeedback = true
//                                    // Hide after 1 second
//                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                                        withAnimation {
//                                            showStartFeedback = false
//                                        }
//                                    }
//                                }
//                                .font(.subheadline)
//                                .foregroundColor(.white)
//                                .frame(minWidth: 0, maxWidth: 100)
//                                .padding(10)
//                                .background(Color.blue)
//                                .cornerRadius(10)
//                                
//                                Button("Save") {
//                                    provideHapticFeedback()
//                                    
//                                    // ARModel action
//                                    arModel.saveCurrentMeasurement()
//                                    
//                                    // Show ephemeral message
//                                    showSaveFeedback = true
//                                    // Hide after 1 second
//                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                                        withAnimation {
//                                            showSaveFeedback = false
//                                        }
//                                    }
//                                }
//                                .font(.subheadline)
//                                .foregroundColor(.white)
//                                .frame(minWidth: 0, maxWidth: 100)
//                                .padding(10)
//                                .background(Color.green)
//                                .cornerRadius(10)
//                            }
//                            .frame(minWidth: 0, maxWidth: 130)
//                            
//                            // Right column: Stats (pixel count, depth, width, angle)
//                            VStack(spacing: 6) {
//                                if let pxSpan = arModel.screenPixelSpanFromEdges {
//                                    Text("Pixel Counter: \(Int(pxSpan)) px")
//                                        .foregroundColor(.white)
//                                } else {
//                                    Text("Pixel Counter: -- px")
//                                        .foregroundColor(.white)
//                                }
//                                
//                                if let centralDepth = arModel.centralDepth {
//                                    Text(String(format: "Central Depth: %.2f m", centralDepth))
//                                        .foregroundColor(.white)
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
//    /// Simple haptic feedback
//    private func provideHapticFeedback() {
//        let generator = UIImpactFeedbackGenerator(style: .medium)
//        generator.impactOccurred()
//    }
//}

import SwiftUI

struct ContentView: View {
    @StateObject var arModel = ARModel()
    
    // States for temporary feedback
    @State private var showStartFeedback: Bool = false
    @State private var showSaveFeedback: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .center) {
                // 1) Live camera feed
                CameraView(arModel: arModel)
                    .edgesIgnoringSafeArea(.all)
                // 2) Optional crosshair line
                GeometryReader { geometry in
                    let screenWidth = geometry.size.width
                    let screenHeight = geometry.size.height
                    let yPosition = screenHeight / 2
                    
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: yPosition))
                        path.addLine(to: CGPoint(x: screenWidth, y: yPosition))
                    }
                    .stroke(Color.red, lineWidth: 2)
                }
                .frame(width: UIScreen.main.bounds.width,
                       height: UIScreen.main.bounds.height)
                
                // 3) Green plus at center
                ZStack {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 2, height: 20)
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 20, height: 2)
                }
                
                // 4) Temporary overlay messages for button presses
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
            // Overlay buttons: Measurements button and Settings button
            .overlay(
                VStack(spacing: 10) {
                    HStack {
                        // Measurements button
                        NavigationLink(destination: MeasurementsView(arModel: arModel)) {
                            Text("Measurements")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.orange)
                                .cornerRadius(10)
                        }
                        Spacer()
                        // Settings button using gear icon
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
                    
                    // Depth UI and controls (unchanged from your original)
                    if let slice = arModel.averagedCentralColumnsDepthFloats(colCount: 5) {
                        DepthMapView(depthData: slice, depthEdges: arModel.depthEdgeIndices)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .frame(height: 200)
                            .padding(.horizontal, 10)
                            .padding(.bottom, -5)
                        
                        HStack(spacing: 15) {
                            VStack(spacing: 15) {
                                Button("Start") {
                                    provideHapticFeedback()
                                    arModel.resetInitialYaw()
                                    showStartFeedback = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        withAnimation { showStartFeedback = false }
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .frame(minWidth: 0, maxWidth: 100)
                                .padding(10)
                                .background(Color.blue)
                                .cornerRadius(10)
                                
                                Button("Save") {
                                    provideHapticFeedback()
                                    arModel.saveCurrentMeasurement()
                                    showSaveFeedback = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        withAnimation { showSaveFeedback = false }
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .frame(minWidth: 0, maxWidth: 100)
                                .padding(10)
                                .background(Color.green)
                                .cornerRadius(10)
                            }
                            .frame(minWidth: 0, maxWidth: 130)
                            
                            VStack(spacing: 6) {
                                if let pxSpan = arModel.screenPixelSpanFromEdges {
                                    Text("Pixel Counter: \(Int(pxSpan)) px")
                                        .foregroundColor(.white)
                                } else {
                                    Text("Pixel Counter: -- px")
                                        .foregroundColor(.white)
                                }
                                
                                if let centralDepth = arModel.centralDepth {
                                    Text(String(format: "Central Depth: %.2f m", centralDepth))
                                        .foregroundColor(.white)
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
    
    private func provideHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
