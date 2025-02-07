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
    @Published var realWidth: Double?  // Now computed as a moving average of the last 3 estimates.
    @Published var colorWidth: Int = 0
    @Published var colorHeight: Int = 0
    
    // Moving average buffer for realWidth.
    private var realWidthBuffer: [Double] = []
    
    // MARK: - CoreMotion-based Yaw Tracking (Quaternion)
    @Published var rotationAngle: Float = 0.0  // Current yaw in degrees [0..360]
    private var initialYaw: Double?
    
    // Additional properties for the spirit level feature.
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    
    // Computed property to determine if the device is “perfectly vertical.”
    var isVertical: Bool {
        let threshold = 2.5 * (.pi / 180.0)
        return abs(abs(pitch) - (.pi / 2)) < threshold
    }
    
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
                  let motion = motion else { return }
            
            // Update yaw.
            let quat = motion.attitude.quaternion
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
            
            // Update pitch and roll for the spirit level feature.
            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll
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
    @Published var scalingConstant: Float = 0.0  // Editable threshold via settings.

    
    func computeDepthEdges() {
        guard let slice = averagedCentralColumnsDepthFloats(colCount: 5) else {
            depthEdgeIndices = []
            edgeDistance = nil
            screenPixelSpanFromEdges = nil
            return
        }
        
        // Step 1: Detect candidate edges based on depth differences.
        var candidateEdges: [Int] = []
        for i in 0..<(slice.count - 1) {
            let diff = abs(slice[i + 1] - slice[i])
            if diff > depthEdgeThreshold {
                candidateEdges.append(i)
            }
        }
        
        // Step 2: For each candidate edge, compute a "characterization" value by sampling depths to its left and right.
        // We use an offset of 2 indices. Boundaries are handled by clamping to the valid index range.
        var characterizedEdges: [(index: Int, charDepth: Double)] = []
        for i in candidateEdges {
            let leftIndex = max(i - 2, 0)
            let rightIndex = min(i + 2, slice.count - 1)
            let leftDepth = Double(slice[leftIndex])
            let rightDepth = Double(slice[rightIndex])
            let charDepth = min(leftDepth, rightDepth)
            characterizedEdges.append((index: i, charDepth: charDepth))
        }
        
        // Keep track of previously identified edges before computing new ones.
        let oldEdges = self.depthEdgeIndices

        // Step 3: Pre-filter out edges whose characterization depth is 1.20m or more.
        let filteredCharacterizedEdges = characterizedEdges.filter { $0.charDepth < 1.20 }

        // Step 4: If more than two candidate edges remain, sort by their characterization depth
        // (lowest = closest) and choose the two with the lowest values.
        var finalEdges: [Int] = []
        if filteredCharacterizedEdges.count >= 2 {
            let sortedEdges = filteredCharacterizedEdges.sorted { $0.charDepth < $1.charDepth }
            finalEdges = Array(sortedEdges.prefix(2)).map { $0.index }.sorted()
        } else {
            finalEdges = []
        }

        // >>> NEW LOGIC: If the newly found edges are too close (< 3 indices apart), revert to old edges. <<<
        if finalEdges.count == 2 {
            let diff = abs(finalEdges[1] - finalEdges[0])
            if diff < 3 {
                finalEdges = oldEdges
            }
        }
        
        
        // Step 5: Update properties on the main thread.
        DispatchQueue.main.async {
            self.depthEdgeIndices = finalEdges
            
            if finalEdges.count >= 2 {
                let first = finalEdges.first!
                let last = finalEdges.last!
                self.edgeDistance = abs(last - first) + 0
                
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
//            print(self.edgeDistance as Any)
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
    
    @Published var constant: Double = 2.0
    
    func computeRealWidth() {
        // Instead of always using the centralDepth,
        // try to use a depth value measured at the object edge.
        // If valid depth edges are detected, take the depth at 2 indices to the right
        // of the left edge and 2 indices to the left of the right edge, then average them.
        var usedDepth: Double? = nil
        if let slice = averagedCentralColumnsDepthFloats(colCount: 5),
           depthEdgeIndices.count >= 2 {
            let leftEdge = depthEdgeIndices.first!
            let rightEdge = depthEdgeIndices.last!
            let leftIndex = min(leftEdge + 2, slice.count - 1)
            let rightIndex = max(rightEdge - 2, 0)
            usedDepth = (Double(slice[leftIndex]) + Double(slice[rightIndex])) / 2.0
//            print("Using new edge-based depth: \(usedDepth ?? 0)")
        } else {
            // Fallback: use the centralDepth if edges aren’t detected.
            usedDepth = centralDepth
//            print("Falling back to central depth: \(usedDepth ?? 0)")
        }
        
        // If required parameters are missing, use the last nonzero value from the buffer.
        guard let dist = edgeDistance,
              let depthValue = usedDepth,
              let focalColor = focalLengthPixels,
              focalColor > 0,
              colorHeight > 0,
              lidarHeight > 0 else {
            
            // Fall back to the last nonzero value in the buffer
            if let lastNonZero = realWidthBuffer.reversed().first(where: { $0 != 0 }) {
                realWidth = lastNonZero
            } else {
                realWidth = nil
            }
            return
        }
        
        // Adjust for difference in resolution between color & LiDAR.
        let focalLidarY = focalColor * (Double(lidarHeight) / Double(colorHeight))
        let adjustedDist = Double(dist) + constant // Constant adjustment can be applied here if needed.
        print(adjustedDist)
        let newWidth = (adjustedDist * depthValue) / focalLidarY
        
        // Update the moving average buffer.
        realWidthBuffer.append(newWidth)
        // Ensure we only keep the most recent 3 values (or fewer if they've been 0 in the past).
        if realWidthBuffer.count > 3 {
            realWidthBuffer.removeFirst()
        }
        
        // Use the moving average ONLY if we have at least 3 nonzero entries.
        let nonZeroValues = realWidthBuffer.filter { $0 != 0 }
        if nonZeroValues.count >= 3 {
            realWidth = nonZeroValues.reduce(0.0, +) / Double(nonZeroValues.count)
        } else {
            // Otherwise, fall back to the last nonzero value in the buffer.
            if let lastNonZero = realWidthBuffer.reversed().first(where: { $0 != 0 }) {
                realWidth = lastNonZero
            } else {
                realWidth = nil
            }
        }
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
