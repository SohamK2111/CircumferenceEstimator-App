//import Foundation
//import SwiftUI
//import ARKit
//import CoreMotion
//import Combine
//
//class ARModel: NSObject, ObservableObject, ARSessionDelegate {
//    // MARK: - LiDAR / Depth Data
//    @Published var fullLiDARFloats: [Float] = []
//    @Published var lidarWidth: Int = 0
//    @Published var lidarHeight: Int = 0
//    @Published var centralDepth: Double?
//    @Published var depthMinValue: Float?
//    @Published var depthMaxValue: Float?
//    @Published var realWidth: Double?
//    @Published var colorWidth: Int = 0
//    @Published var colorHeight: Int = 0
//    
//    // MARK: - CoreMotion-based Yaw Tracking (Quaternion)
//    @Published var rotationAngle: Float = 0.0  // Current yaw in degrees [0..360]
//    private var initialYaw: Double?
//    
//    // CoreMotion manager
//    private let motionManager = CMMotionManager()
//    
//    // MARK: - AR Session
//    var arSession: ARSession
//    
//    override init() {
//        self.arSession = ARSession()
//        super.init()
//        
//        // ARSession delegate for LiDAR or environment depth
//        arSession.delegate = self
//        startARSession()
//        
//        // Start device motion updates for yaw
//        startCoreMotionUpdates()
//    }
//
//    // MARK: - Start AR Session
//    private func startARSession() {
//        let configuration = ARWorldTrackingConfiguration()
//        configuration.isLightEstimationEnabled = true
//        
//        // If device supports sceneDepth, we prefer that for LiDAR
//        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
//            configuration.frameSemantics.insert(.sceneDepth)
//            configuration.planeDetection = [.horizontal, .vertical]
//            print("Using ARKit sceneDepth (LiDAR if available).")
//        }
//        else if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
//            // Some devices may only support smoothedSceneDepth
//            configuration.frameSemantics.insert(.smoothedSceneDepth)
//            configuration.planeDetection = [.horizontal, .vertical]
//            print("Using ARKit smoothedSceneDepth (environment depth).")
//        }
//        else {
//            print("No AR depth support on this device.")
//        }
//        
//        arSession.run(configuration)
//        print("AR session started.")
//    }
//    
//    // MARK: - CoreMotion for Yaw (using quaternion)
//    private func startCoreMotionUpdates() {
//        guard motionManager.isDeviceMotionAvailable else {
//            print("Device Motion not available.")
//            return
//        }
//        
//        // Update ~10 times per second
//        motionManager.deviceMotionUpdateInterval = 1.0 / 10.0
//        
//        // Start Device Motion updates on main queue
//        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
//            guard let self = self,
//                  let quat = motion?.attitude.quaternion else {
//                return
//            }
//            
//            // Convert quaternion -> yaw in radians, range -π...+π
//            let w = quat.w
//            let x = quat.x
//            let y = quat.y
//            let z = quat.z
//            
//            let siny_cosp = 2.0 * (w * z + x * y)
//            let cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
//            let currentYaw = atan2(siny_cosp, cosy_cosp) // [-π...+π]
//            
//            // If no baseline, set it now
//            if self.initialYaw == nil {
//                self.initialYaw = currentYaw
//            }
//            
//            // Subtract baseline => relative angle in [-π..+π]
//            let relative = currentYaw - (self.initialYaw ?? 0.0)
//            
//            // Normalize to [0..2π]
//            var normalized = relative
//            while normalized < 0 { normalized += (2.0 * .pi) }
//            while normalized > 2.0 * .pi { normalized -= (2.0 * .pi) }
//            
//            // Convert to degrees
//            let relativeYawDegrees = normalized * (180.0 / .pi)
//            
//            // Update published property
//            self.rotationAngle = Float(relativeYawDegrees)
//        }
//    }
//    
//    /// Called when user taps "Start" to reset the baseline yaw
//    func resetInitialYaw() {
//        guard let motion = motionManager.deviceMotion else {
//            print("Could not get current device motion from CoreMotion")
//            return
//        }
//        
//        let q = motion.attitude.quaternion
//        let w = q.w
//        let x = q.x
//        let y = q.y
//        let z = q.z
//        
//        // Convert quaternion -> yaw in radians
//        let siny_cosp = 2.0 * (w * z + x * y)
//        let cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
//        let yaw = atan2(siny_cosp, cosy_cosp)  // [-π...+π]
//        
//        initialYaw = yaw
//        print("Initial yaw set to \(yaw) (radians).")
//    }
//    
//    // MARK: - ARSessionDelegate (Depth Only)
//    func session(_ session: ARSession, didUpdate frame: ARFrame) {
//        // We are not using ARKit's transform for yaw,
//        // only for depth data, so this can remain empty.
//    }
//    
//    func session(_ session: ARSession, didFailWithError error: Error) {
//        print("AR session failed: \(error.localizedDescription)")
//    }
//    
//    func sessionWasInterrupted(_ session: ARSession) {
//        print("AR session was interrupted.")
//    }
//    
//    func sessionInterruptionEnded(_ session: ARSession) {
//        print("AR session interruption ended.")
//    }
//
//    // MARK: - Edge Detection & Depth Processing
//    @Published var depthEdgeIndices: [Int] = []
//    var depthEdgeThreshold: Float = 0.3
//    var depthEdgeCount: Int { depthEdgeIndices.count }
//    
//    var depthEdgePixelSpan: Int? {
//        guard depthEdgeIndices.count >= 2 else { return nil }
//        return abs(depthEdgeIndices.last! - depthEdgeIndices.first!)
//    }
//    
//    var computedWidthFromDepthEdges: Double? {
//        guard let span = depthEdgePixelSpan,
//              let cDepth = centralDepth,
//              let focal = focalLengthPixels,
//              focal > 0 else {
//            return nil
//        }
//        return (Double(span) * cDepth) / focal
//    }
//
//    @Published var displayTransform: CGAffineTransform = .identity
//    @Published var screenPixelSpanFromEdges: CGFloat? = nil
//
//    func computeDepthEdges() {
//        guard let slice = averagedCentralColumnsDepthFloats(colCount: 5) else {
//            depthEdgeIndices = []
//            edgeDistance = nil
//            screenPixelSpanFromEdges = nil
//            return
//        }
//        
//        var edges: [Int] = []
//        for i in 0..<(slice.count - 1) {
//            let diff = abs(slice[i + 1] - slice[i])
//            if diff > depthEdgeThreshold {
//                edges.append(i)
//            }
//        }
//        
//        DispatchQueue.main.async {
//            self.depthEdgeIndices = edges
//            
//            if edges.count >= 2 {
//                let first = edges.first!
//                let last = edges.last!
//                self.edgeDistance = abs(last - first)
//
//                if self.edgeDistance != nil, self.edgeDistance! > 0 {
//                    // You can adjust this scaling for your needs
//                    self.screenPixelSpanFromEdges = CGFloat(self.edgeDistance!) *
//                                                    UIScreen.main.bounds.width * 3 / 118.0
//                } else {
//                    self.screenPixelSpanFromEdges = nil
//                }
//            } else {
//                self.edgeDistance = nil
//                self.screenPixelSpanFromEdges = nil
//            }
//        }
//    }
//
//    // MARK: - Average central columns => 1D vertical slice
//    func averagedCentralColumnsDepthFloats(colCount: Int = 5) -> [Float]? {
//        guard !fullLiDARFloats.isEmpty, lidarWidth > 0, lidarHeight > 0 else {
//            return nil
//        }
//
//        let centerX = lidarWidth / 2
//        let half = colCount / 2
//        let startX = max(centerX - half, 0)
//        let endX = min(centerX + half, lidarWidth - 1)
//
//        var averagedColumn = [Float](repeating: 0, count: lidarHeight)
//
//        for y in 0..<lidarHeight {
//            var sum: Float = 0
//            var validCount = 0
//            for col in startX...endX {
//                let idx = y * lidarWidth + col
//                let val = fullLiDARFloats[idx]
//                if val.isFinite {
//                    sum += val
//                    validCount += 1
//                }
//            }
//            averagedColumn[y] = validCount > 0 ? (sum / Float(validCount)) : .nan
//        }
//
//        return averagedColumn
//    }
//
//    // MARK: - Real Width using Depth & Focal Length
//    @Published var edgeDistance: Int? {
//        didSet {
//            computeRealWidth()
//        }
//    }
//
//    var focalLengthPixels: Double? {
//        didSet {
//            computeRealWidth()
//        }
//    }
//
//    func computeRealWidth() {
//        guard let dist = edgeDistance,
//              let depth = centralDepth,
//              let focalColor = focalLengthPixels,
//              focalColor > 0,
//              colorHeight > 0,
//              lidarHeight > 0
//        else {
//            realWidth = nil
//            return
//        }
//
//        // Adjust for difference in resolution between color & LiDAR
//        let focalLidarY = focalColor * (Double(lidarHeight) / Double(colorHeight))
//        realWidth = (Double(dist) * depth) / focalLidarY
//    }
//
//    // MARK: - Convert LiDAR coordinate => screen coordinate
//    func lidarToScreenPoint(col: Int, row: Int) -> CGPoint? {
//        guard lidarWidth > 0, lidarHeight > 0 else { return nil }
//
//        let col_normalized = CGFloat(Double(col) + 0.5) / CGFloat(lidarWidth)
//        let row_normalized = CGFloat(Double(row) + 0.5) / CGFloat(lidarHeight)
//
//        let normalizedPt = CGPoint(x: col_normalized, y: row_normalized)
//        return normalizedPt.applying(displayTransform)
//    }
//
//    // MARK: - Measurement Storage
//    struct Measurement: Identifiable {
//        let id = UUID()
//        let timestamp: Date
//        let edgeDistance: Int
//        let centralDepth: Double
//        let realWidth: Double
//        let rotationAngle: Float
//    }
//
//    @Published var measurements: [Measurement] = []
//    
//    func saveCurrentMeasurement() {
//        if let dist = edgeDistance,
//           let depth = centralDepth,
//           let width = realWidth {
//            let measurement = Measurement(
//                            timestamp: Date(),
//                            edgeDistance: dist,
//                            centralDepth: depth,
//                            realWidth: width,
//                            rotationAngle: rotationAngle
//                        )
//            measurements.append(measurement)
//        }
//    }
//}
//import Foundation
//import SwiftUI
//import ARKit
//import CoreMotion
//import Combine
//
//class ARModel: NSObject, ObservableObject, ARSessionDelegate {
//    // MARK: - LiDAR / Depth Data
//    @Published var fullLiDARFloats: [Float] = []
//    @Published var lidarWidth: Int = 0
//    @Published var lidarHeight: Int = 0
//    @Published var centralDepth: Double?
//    @Published var depthMinValue: Float?
//    @Published var depthMaxValue: Float?
//    @Published var realWidth: Double?
//    @Published var colorWidth: Int = 0
//    @Published var colorHeight: Int = 0
//    
//    // MARK: - CoreMotion-based Yaw Tracking (Quaternion)
//    @Published var rotationAngle: Float = 0.0  // Current yaw in degrees [0..360]
//    private var initialYaw: Double?
//    
//    // CoreMotion manager
//    private let motionManager = CMMotionManager()
//    
//    // MARK: - AR Session
//    var arSession: ARSession
//    
//    override init() {
//        self.arSession = ARSession()
//        super.init()
//        
//        // Set ARSession delegate for depth processing.
//        arSession.delegate = self
//        startARSession()
//        startCoreMotionUpdates()
//    }
//    
//    // MARK: - Start AR Session
//    private func startARSession() {
//        let configuration = ARWorldTrackingConfiguration()
//        configuration.isLightEstimationEnabled = true
//        
//        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
//            configuration.frameSemantics.insert(.sceneDepth)
//            configuration.planeDetection = [.horizontal, .vertical]
//            print("Using ARKit sceneDepth (LiDAR if available).")
//        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
//            configuration.frameSemantics.insert(.smoothedSceneDepth)
//            configuration.planeDetection = [.horizontal, .vertical]
//            print("Using ARKit smoothedSceneDepth (environment depth).")
//        } else {
//            print("No AR depth support on this device.")
//        }
//        
//        arSession.run(configuration)
//        print("AR session started.")
//    }
//    
//    // MARK: - CoreMotion Updates
//    private func startCoreMotionUpdates() {
//        guard motionManager.isDeviceMotionAvailable else {
//            print("Device Motion not available.")
//            return
//        }
//        
//        motionManager.deviceMotionUpdateInterval = 1.0 / 10.0
//        
//        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
//            guard let self = self,
//                  let quat = motion?.attitude.quaternion else { return }
//            
//            let w = quat.w
//            let x = quat.x
//            let y = quat.y
//            let z = quat.z
//            
//            let siny_cosp = 2.0 * (w * z + x * y)
//            let cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
//            let currentYaw = atan2(siny_cosp, cosy_cosp)
//            
//            if self.initialYaw == nil {
//                self.initialYaw = currentYaw
//            }
//            
//            let relative = currentYaw - (self.initialYaw ?? 0.0)
//            var normalized = relative
//            while normalized < 0 { normalized += (2.0 * .pi) }
//            while normalized > 2.0 * .pi { normalized -= (2.0 * .pi) }
//            
//            let relativeYawDegrees = normalized * (180.0 / .pi)
//            self.rotationAngle = Float(relativeYawDegrees)
//        }
//    }
//    
//    /// Resets the baseline yaw.
//    func resetInitialYaw() {
//        guard let motion = motionManager.deviceMotion else {
//            print("Could not get current device motion from CoreMotion")
//            return
//        }
//        
//        let q = motion.attitude.quaternion
//        let w = q.w, x = q.x, y = q.y, z = q.z
//        let siny_cosp = 2.0 * (w * z + x * y)
//        let cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
//        let yaw = atan2(siny_cosp, cosy_cosp)
//        initialYaw = yaw
//        print("Initial yaw set to \(yaw) (radians).")
//    }
//    
//    // MARK: - ARSessionDelegate Methods
//    func session(_ session: ARSession, didUpdate frame: ARFrame) {
//        // Depth processing can be handled elsewhere.
//    }
//    
//    func session(_ session: ARSession, didFailWithError error: Error) {
//        print("AR session failed: \(error.localizedDescription)")
//    }
//    
//    func sessionWasInterrupted(_ session: ARSession) {
//        print("AR session was interrupted.")
//    }
//    
//    func sessionInterruptionEnded(_ session: ARSession) {
//        print("AR session interruption ended.")
//    }
//    
//    // MARK: - Edge Detection & Depth Processing
//    @Published var depthEdgeIndices: [Int] = []
//    @Published var depthEdgeThreshold: Float = 0.3  // Editable threshold via settings.
//    
//    // New property for Gaussian sigma (absolute value in terms of index units).
//    @Published var gaussianSigma: Double = 40.0  // Default sigma; adjust via settings.
//    
//    var depthEdgeCount: Int { depthEdgeIndices.count }
//    
//    var depthEdgePixelSpan: Int? {
//        guard depthEdgeIndices.count >= 2 else { return nil }
//        return abs(depthEdgeIndices.last! - depthEdgeIndices.first!)
//    }
//    
//    var computedWidthFromDepthEdges: Double? {
//        guard let span = depthEdgePixelSpan,
//              let cDepth = centralDepth,
//              let focal = focalLengthPixels,
//              focal > 0 else { return nil }
//        return (Double(span) * cDepth) / focal
//    }
//    
//    @Published var displayTransform: CGAffineTransform = .identity
//    @Published var screenPixelSpanFromEdges: CGFloat? = nil
//    
//    func computeDepthEdges() {
//        guard let slice = averagedCentralColumnsDepthFloats(colCount: 5) else {
//            depthEdgeIndices = []
//            edgeDistance = nil
//            screenPixelSpanFromEdges = nil
//            return
//        }
//        
//        var edges: [Int] = []
//        let centerIndex = slice.count / 2
//        let sigma = gaussianSigma  // Use the user-adjustable sigma value.
//        
//        for i in 0..<(slice.count - 1) {
//            let diff = abs(slice[i + 1] - slice[i])
//            let distanceFromCenter = Double(i) - Double(centerIndex)
//            let gaussianWeight = exp(-(distanceFromCenter * distanceFromCenter) / (2 * sigma * sigma))
//            let weightedDiff = diff * Float(gaussianWeight)
//            if weightedDiff > depthEdgeThreshold {
//                edges.append(i)
//            }
//        }
//        
//        DispatchQueue.main.async {
//            self.depthEdgeIndices = edges
//            
//            if edges.count >= 2 {
//                let first = edges.first!
//                let last = edges.last!
//                self.edgeDistance = abs(last - first)
//                
//                if let edgeDist = self.edgeDistance, edgeDist > 0 {
//                    // Scaling factor can be adjusted as needed.
//                    self.screenPixelSpanFromEdges = CGFloat(edgeDist) *
//                                                    UIScreen.main.bounds.width * 3 / 118.0
//                } else {
//                    self.screenPixelSpanFromEdges = nil
//                }
//            } else {
//                self.edgeDistance = nil
//                self.screenPixelSpanFromEdges = nil
//            }
//        }
//    }
//    
//    // MARK: - Average Central Columns to Create a 1D Depth Slice
//    func averagedCentralColumnsDepthFloats(colCount: Int = 5) -> [Float]? {
//        guard !fullLiDARFloats.isEmpty, lidarWidth > 0, lidarHeight > 0 else {
//            return nil
//        }
//        
//        let centerX = lidarWidth / 2
//        let half = colCount / 2
//        let startX = max(centerX - half, 0)
//        let endX = min(centerX + half, lidarWidth - 1)
//        
//        var averagedColumn = [Float](repeating: 0, count: lidarHeight)
//        
//        for y in 0..<lidarHeight {
//            var sum: Float = 0
//            var validCount = 0
//            for col in startX...endX {
//                let idx = y * lidarWidth + col
//                let val = fullLiDARFloats[idx]
//                if val.isFinite {
//                    sum += val
//                    validCount += 1
//                }
//            }
//            averagedColumn[y] = validCount > 0 ? (sum / Float(validCount)) : .nan
//        }
//        
//        return averagedColumn
//    }
//    
//    // MARK: - Real Width Calculation using Depth & Focal Length
//    @Published var edgeDistance: Int? {
//        didSet { computeRealWidth() }
//    }
//    
//    var focalLengthPixels: Double? {
//        didSet { computeRealWidth() }
//    }
//    
//    func computeRealWidth() {
//        guard let dist = edgeDistance,
//              let depth = centralDepth,
//              let focalColor = focalLengthPixels,
//              focalColor > 0,
//              colorHeight > 0,
//              lidarHeight > 0 else {
//            realWidth = nil
//            return
//        }
//        
//        let focalLidarY = focalColor * (Double(lidarHeight) / Double(colorHeight))
//        realWidth = (Double(dist) * depth) / focalLidarY
//    }
//    
//    // MARK: - Convert LiDAR Coordinates to Screen Coordinates
//    func lidarToScreenPoint(col: Int, row: Int) -> CGPoint? {
//        guard lidarWidth > 0, lidarHeight > 0 else { return nil }
//        let colNormalized = CGFloat(Double(col) + 0.5) / CGFloat(lidarWidth)
//        let rowNormalized = CGFloat(Double(row) + 0.5) / CGFloat(lidarHeight)
//        let normalizedPt = CGPoint(x: colNormalized, y: rowNormalized)
//        return normalizedPt.applying(displayTransform)
//    }
//    
//    // MARK: - Measurement Storage
//    struct Measurement: Identifiable {
//        let id = UUID()
//        let timestamp: Date
//        let edgeDistance: Int
//        let centralDepth: Double
//        let realWidth: Double
//        // Mutable for editing.
//        var rotationAngle: Float
//    }
//    
//    @Published var measurements: [Measurement] = []
//    
//    func saveCurrentMeasurement() {
//        if let dist = edgeDistance,
//           let depth = centralDepth,
//           let width = realWidth {
//            let measurement = Measurement(
//                timestamp: Date(),
//                edgeDistance: dist,
//                centralDepth: depth,
//                realWidth: width,
//                rotationAngle: rotationAngle
//            )
//            measurements.append(measurement)
//        }
//    }
//}

import Foundation
import SwiftUI
import ARKit
import CoreMotion
import Combine

class ARModel: NSObject, ObservableObject, ARSessionDelegate {
    // MARK: - LiDAR / Depth Data
    @Published var fullLiDARFloats: [Float] = []
    @Published var lidarWidth: Int = 0
    @Published var lidarHeight: Int = 0
    @Published var centralDepth: Double?
    @Published var depthMinValue: Float?
    @Published var depthMaxValue: Float?
    @Published var realWidth: Double?
    @Published var colorWidth: Int = 0
    @Published var colorHeight: Int = 0
    
    // MARK: - CoreMotion-based Yaw Tracking (Quaternion)
    @Published var rotationAngle: Float = 0.0  // Current yaw in degrees [0..360]
    private var initialYaw: Double?
    
    // CoreMotion manager
    private let motionManager = CMMotionManager()
    
    // MARK: - AR Session
    var arSession: ARSession
    
    override init() {
        self.arSession = ARSession()
        super.init()
        
        // Set ARSession delegate for depth processing.
        arSession.delegate = self
        startARSession()
        startCoreMotionUpdates()
    }
    
    // MARK: - Start AR Session
    private func startARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
            configuration.planeDetection = [.horizontal, .vertical]
            print("Using ARKit sceneDepth (LiDAR if available).")
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
            configuration.planeDetection = [.horizontal, .vertical]
            print("Using ARKit smoothedSceneDepth (environment depth).")
        } else {
            print("No AR depth support on this device.")
        }
        
        arSession.run(configuration)
        print("AR session started.")
    }
    
    // MARK: - CoreMotion Updates
    private func startCoreMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device Motion not available.")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 10.0
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self,
                  let quat = motion?.attitude.quaternion else { return }
            
            let w = quat.w
            let x = quat.x
            let y = quat.y
            let z = quat.z
            
            let siny_cosp = 2.0 * (w * z + x * y)
            let cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
            let currentYaw = atan2(siny_cosp, cosy_cosp)
            
            if self.initialYaw == nil {
                self.initialYaw = currentYaw
            }
            
            let relative = currentYaw - (self.initialYaw ?? 0.0)
            var normalized = relative
            while normalized < 0 { normalized += (2.0 * .pi) }
            while normalized > 2.0 * .pi { normalized -= (2.0 * .pi) }
            
            let relativeYawDegrees = normalized * (180.0 / .pi)
            self.rotationAngle = Float(relativeYawDegrees)
        }
    }
    
    /// Resets the baseline yaw.
    func resetInitialYaw() {
        guard let motion = motionManager.deviceMotion else {
            print("Could not get current device motion from CoreMotion")
            return
        }
        
        let q = motion.attitude.quaternion
        let w = q.w, x = q.x, y = q.y, z = q.z
        let siny_cosp = 2.0 * (w * z + x * y)
        let cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
        let yaw = atan2(siny_cosp, cosy_cosp)
        initialYaw = yaw
        print("Initial yaw set to \(yaw) (radians).")
    }
    
    // MARK: - ARSessionDelegate Methods
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Depth processing can be handled elsewhere.
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR session failed: \(error.localizedDescription)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("AR session was interrupted.")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("AR session interruption ended.")
    }
    
    // MARK: - Edge Detection & Depth Processing
    @Published var depthEdgeIndices: [Int] = []
    @Published var depthEdgeThreshold: Float = 0.3  // Editable threshold via settings.
    
    // Gaussian sigma property removed; edges are now detected without Gaussian weighting.
    
    var depthEdgeCount: Int { depthEdgeIndices.count }
    
    var depthEdgePixelSpan: Int? {
        guard depthEdgeIndices.count >= 2 else { return nil }
        return abs(depthEdgeIndices.last! - depthEdgeIndices.first!)
    }
    
    var computedWidthFromDepthEdges: Double? {
        guard let span = depthEdgePixelSpan,
              let cDepth = centralDepth,
              let focal = focalLengthPixels,
              focal > 0 else { return nil }
        return (Double(span) * cDepth) / focal
    }
    
    @Published var displayTransform: CGAffineTransform = .identity
    @Published var screenPixelSpanFromEdges: CGFloat? = nil
    
    func computeDepthEdges() {
        guard let slice = averagedCentralColumnsDepthFloats(colCount: 5) else {
            depthEdgeIndices = []
            edgeDistance = nil
            screenPixelSpanFromEdges = nil
            return
        }
        
        var edges: [Int] = []
        for i in 0..<(slice.count - 1) {
            let diff = abs(slice[i + 1] - slice[i])
            if diff > depthEdgeThreshold {
                edges.append(i)
            }
        }
        
        DispatchQueue.main.async {
            self.depthEdgeIndices = edges
            
            if edges.count >= 2 {
                let first = edges.first!
                let last = edges.last!
                self.edgeDistance = abs(last - first)
                
                if let edgeDist = self.edgeDistance, edgeDist > 0 {
                    // Scaling factor can be adjusted as needed.
                    self.screenPixelSpanFromEdges = CGFloat(edgeDist) *
                                                    UIScreen.main.bounds.width * 3 / 118.0
                } else {
                    self.screenPixelSpanFromEdges = nil
                }
            } else {
                self.edgeDistance = nil
                self.screenPixelSpanFromEdges = nil
            }
        }
    }
    
    // MARK: - Average Central Columns to Create a 1D Depth Slice
    func averagedCentralColumnsDepthFloats(colCount: Int = 5) -> [Float]? {
        guard !fullLiDARFloats.isEmpty, lidarWidth > 0, lidarHeight > 0 else {
            return nil
        }
        
        let centerX = lidarWidth / 2
        let half = colCount / 2
        let startX = max(centerX - half, 0)
        let endX = min(centerX + half, lidarWidth - 1)
        
        var averagedColumn = [Float](repeating: 0, count: lidarHeight)
        
        for y in 0..<lidarHeight {
            var sum: Float = 0
            var validCount = 0
            for col in startX...endX {
                let idx = y * lidarWidth + col
                let val = fullLiDARFloats[idx]
                if val.isFinite {
                    sum += val
                    validCount += 1
                }
            }
            averagedColumn[y] = validCount > 0 ? (sum / Float(validCount)) : .nan
        }
        
        return averagedColumn
    }
    
    // MARK: - Real Width Calculation using Depth & Focal Length
    @Published var edgeDistance: Int? {
        didSet { computeRealWidth() }
    }
    
    var focalLengthPixels: Double? {
        didSet { computeRealWidth() }
    }
    
    func computeRealWidth() {
        guard let dist = edgeDistance,
              let depth = centralDepth,
              let focalColor = focalLengthPixels,
              focalColor > 0,
              colorHeight > 0,
              lidarHeight > 0 else {
            realWidth = nil
            return
        }
        
        // Adjust for difference in resolution between color & LiDAR
        let focalLidarY = focalColor * (Double(lidarHeight) / Double(colorHeight))
        
        // Add a constant value of 4 to the edge distance.
        let adjustedDist = Double(dist) + 1.0 // added a constant to try to account for underestimates
        realWidth = (adjustedDist * depth) / focalLidarY
    }
    
    // MARK: - Convert LiDAR Coordinates to Screen Coordinates
    func lidarToScreenPoint(col: Int, row: Int) -> CGPoint? {
        guard lidarWidth > 0, lidarHeight > 0 else { return nil }
        let colNormalized = CGFloat(Double(col) + 0.5) / CGFloat(lidarWidth)
        let rowNormalized = CGFloat(Double(row) + 0.5) / CGFloat(lidarHeight)
        let normalizedPt = CGPoint(x: colNormalized, y: rowNormalized)
        return normalizedPt.applying(displayTransform)
    }
    
    // MARK: - Measurement Storage
    struct Measurement: Identifiable {
        let id = UUID()
        let timestamp: Date
        let edgeDistance: Int
        let centralDepth: Double
        let realWidth: Double
        // Mutable for editing.
        var rotationAngle: Float
    }
    
    @Published var measurements: [Measurement] = []
    
    func saveCurrentMeasurement() {
        if let dist = edgeDistance,
           let depth = centralDepth,
           let width = realWidth {
            let measurement = Measurement(
                timestamp: Date(),
                edgeDistance: dist,
                centralDepth: depth,
                realWidth: width,
                rotationAngle: rotationAngle
            )
            measurements.append(measurement)
        }
    }
    
}
