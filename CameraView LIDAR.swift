import SwiftUI
import ARKit
import SceneKit

struct CameraView: UIViewRepresentable {
    @ObservedObject var arModel: ARModel
    
    func makeCoordinator() -> Coordinator {
        Coordinator(arModel: arModel)
    }
    
    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        
        // ARKit delegates
        sceneView.session.delegate = context.coordinator
        sceneView.delegate = context.coordinator
        
        // Create ARWorldTrackingConfiguration for LiDAR
        let config = ARWorldTrackingConfiguration()
        
        // Check if device supports LiDAR-based sceneDepth
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
            config.planeDetection = [.horizontal, .vertical]
            sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            print("LiDAR is available and session started.")
        } else {
            print("LiDAR is NOT available on this device.")
        }
        
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Nothing to update dynamically
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, ARSessionDelegate, ARSCNViewDelegate {
        private var lastSampleTime = Date()
        weak var sceneView: ARSCNView?
        
        var arModel: ARModel
        
        init(arModel: ARModel) {
            self.arModel = arModel
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didApplyConstraintsAtTime time: TimeInterval) {
            if sceneView == nil, let scnView = renderer as? ARSCNView {
                sceneView = scnView
            }
        }
        
        // MARK: - ARSessionDelegate
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Throttle LiDAR sampling to ~10Hz
            guard Date().timeIntervalSince(lastSampleTime) >= 0.1 else { return }
            lastSampleTime = Date()
            
            // 1) Get color-camera resolution
            let colorRes = frame.camera.imageResolution
            // e.g. 1920x1440 on some devices
            let w = Int(colorRes.width)
            let h = Int(colorRes.height)
//            print("width: \(w), height: \(h)")
            
            // 2) Intrinsics => focal length in color-camera space
            let intrinsics = frame.camera.intrinsics
            let fx = Double(intrinsics[0][0])
            let fy = Double(intrinsics[1][1])
            let focalLengthColorSpace = (fx + fy) / 2.0

            // 3) Send to the ARModel on main thread
            DispatchQueue.main.async {
                // Store color resolution
                self.arModel.colorWidth  = w
                self.arModel.colorHeight = h

                // Store the focal length (still in color-cam pixel units)
                self.arModel.focalLengthPixels = focalLengthColorSpace
            }
            
            // 1) Update the displayTransform for the current orientation & viewport
            let orientation = UIInterfaceOrientation.portrait
            let size = UIScreen.main.bounds.size
            let transform = frame.displayTransform(for: orientation, viewportSize: size)
            
            DispatchQueue.main.async {
                self.arModel.displayTransform = transform
            }
            
            // 2) LiDAR Depth
            if let depthData = frame.sceneDepth {
                processLiDARDepthData(depthData, frame: frame)
            }
            
        }
        
        // MARK: - Process LiDAR Depth
        func processLiDARDepthData(_ depthData: ARDepthData, frame: ARFrame) {
            let depthMap = depthData.depthMap
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
            
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }
            
            let floatPtr = baseAddress.bindMemory(to: Float32.self, capacity: width * height)
            
            // 1) Store the entire float array in ARModel
            var floatArray = [Float](repeating: 0, count: width * height)
            for i in 0..<(width * height) {
                floatArray[i] = floatPtr[i]
            }
            
            // 2) The center pixel
            let centerX = width / 2
            let centerY = height / 2
            let centerIndex = centerY * width + centerX
            let centerDepthMeters = floatPtr[centerIndex]
            
            // 3) Dispatch to main
            DispatchQueue.main.async {
                self.arModel.fullLiDARFloats = floatArray
                self.arModel.lidarWidth = width
                self.arModel.lidarHeight = height
                self.arModel.centralDepth = Double(centerDepthMeters)
            }
            
            // 4) min/max for debugging
            var minVal = Float.greatestFiniteMagnitude
            var maxVal = -Float.greatestFiniteMagnitude
            
            for i in 0..<(width * height) {
                let d = floatPtr[i]
                if d.isFinite {
                    minVal = min(minVal, d)
                    maxVal = max(maxVal, d)
                }
            }
            
            guard minVal < maxVal else {
                print("LiDAR depth uniform or invalid, skipping edge detection.")
                return
            }
            
            
            DispatchQueue.main.async {
                self.arModel.depthMinValue = minVal
                self.arModel.depthMaxValue = maxVal
                
                // Now compute the 1D edge indices after updating fullLiDARFloats
                self.arModel.computeDepthEdges()
            }
        }
    }
}
