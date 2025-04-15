import SwiftUI
import ARKit
import SceneKit

// MARK: - CameraView
struct CameraView: UIViewRepresentable {
    @ObservedObject var arModel: ARModel
        
    func makeCoordinator() -> Coordinator {
        Coordinator(arModel: arModel)
    }
        
    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.session.delegate = context.coordinator
        sceneView.delegate = context.coordinator
            
        // Set the ARModel's session to the one from ARSCNView.
        arModel.setSession(sceneView.session)
            
        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
            config.planeDetection = []
            sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            print("LiDAR is available and session started.")
        } else {
            print("LiDAR is NOT available on this device.")
        }
            
        return sceneView
    }
        
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Restart the session if needed.
        if uiView.session.configuration == nil {
            let config = ARWorldTrackingConfiguration()
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                config.frameSemantics.insert(.sceneDepth)
                config.planeDetection = [.horizontal, .vertical]
            }
            uiView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        }
    }
        
    // Called when the view is removed from the hierarchy.
    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
        print("ARSession paused as CameraView is dismantled.")
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, ARSessionDelegate, ARSCNViewDelegate {
        // Timestamp for throttling.
        private var lastSampleTime = Date()
        // Flag to prevent overlapping frame processing.
        private var isProcessingFrame = false

        weak var sceneView: ARSCNView?
        var arModel: ARModel
        // Dedicated processing queue.
        private let processingQueue = DispatchQueue(label: "com.example.ARProcessingQueue", qos: .userInitiated)

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
            // Throttle to about 10Hz; process one frame at a time.
            guard Date().timeIntervalSince(lastSampleTime) >= 0.1, !isProcessingFrame else {
                return
            }
            lastSampleTime = Date()
            isProcessingFrame = true

            processingQueue.async { [weak self] in
                guard let self = self else { return }
                autoreleasepool {
                    // 1) Get color-camera resolution.
                    let colorRes = frame.camera.imageResolution
                    let width = Int(colorRes.width)
                    let height = Int(colorRes.height)

                    // 2) Compute focal length in color-camera space.
                    let intrinsics = frame.camera.intrinsics
                    let fx = Double(intrinsics[0][0])
                    let fy = Double(intrinsics[1][1])
                    let focalLengthColorSpace = (fx + fy) / 2.0

                    // 3) Prepare display transform.
                    let orientation = UIInterfaceOrientation.portrait
                    let size = UIScreen.main.bounds.size
                    let transform = frame.displayTransform(for: orientation, viewportSize: size)

                    // 4) Process LiDAR Depth Data if available.
                    if let depthData = frame.sceneDepth {
                        let depthMap = depthData.depthMap
                        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
                        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

                        let depthWidth = CVPixelBufferGetWidth(depthMap)
                        let depthHeight = CVPixelBufferGetHeight(depthMap)
                        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
                            self.isProcessingFrame = false
                            return
                        }
                        let floatPtr = baseAddress.bindMemory(to: Float32.self, capacity: depthWidth * depthHeight)
                        var floatArray = [Float](repeating: 0, count: depthWidth * depthHeight)
                        for i in 0..<(depthWidth * depthHeight) {
                            floatArray[i] = floatPtr[i]
                        }
                        let centerX = depthWidth / 2
                        let centerY = depthHeight / 2
                        let centerIndex = centerY * depthWidth + centerX
                        let centerDepthMeters = floatPtr[centerIndex]

                        // 5) Dispatch UI updates on the main thread.
                        DispatchQueue.main.async {
                            self.arModel.colorWidth  = width
                            self.arModel.colorHeight = height
                            self.arModel.focalLengthPixels = focalLengthColorSpace
                            self.arModel.displayTransform = transform
                            self.arModel.fullLiDARFloats = floatArray
                            self.arModel.lidarWidth = depthWidth
                            self.arModel.lidarHeight = depthHeight
                            // Fallback: use central pixel depth if no edges are later detected.
                            self.arModel.centralDepth = Double(centerDepthMeters)
                            
                            // Optionally update min/max depth values.
                            if let minVal = floatArray.filter({ $0.isFinite }).min(),
                               let maxVal = floatArray.filter({ $0.isFinite }).max(),
                               minVal < maxVal {
                                self.arModel.depthMinValue = minVal
                                self.arModel.depthMaxValue = maxVal
                            }
                            
                            // Compute depth edges, which may update centralDepth.
                            self.arModel.computeDepthEdges()
                        }
                    } else {
                        // If no depth data is available, just update the color camera parameters.
                        DispatchQueue.main.async {
                            self.arModel.colorWidth  = width
                            self.arModel.colorHeight = height
                            self.arModel.focalLengthPixels = focalLengthColorSpace
                            self.arModel.displayTransform = transform
                        }
                    }
                }
                // Mark processing complete.
                self.isProcessingFrame = false
            }
        }
    }
}
