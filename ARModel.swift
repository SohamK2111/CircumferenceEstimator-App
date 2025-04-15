import Foundation
import SwiftUI
import ARKit
import CoreMotion
import Combine
import SceneKit

enum SensorType {
    case lidar
    case trueDepth
}

// MARK: - ARModel
class ARModel: NSObject, ObservableObject, ARSessionDelegate {
    
    // MARK: LiDAR / Depth Data
    @Published var fullLiDARFloats: [Float] = []
    @Published var lidarWidth: Int = 0
    @Published var lidarHeight: Int = 0
    @Published var centralDepth: Double?
    @Published var depthMinValue: Float?
    @Published var depthMaxValue: Float?
    @Published var realWidth: Double?
    @Published var colorWidth: Int = 0
    @Published var colorHeight: Int = 0
    @Published var simpsonMaxDeriv: Double = 120
    @Published var variance: Double = 0

    @Published var isTestMode: Bool = true

    private var realWidthBuffer: [Double] = []

    // MARK: CoreMotion Yaw Tracking
    @Published var rotationAngle: Float = 0.0
    private var initialYaw: Double?

    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0

    var isVertical: Bool {
        let threshold = 2.5 * (.pi / 180.0)
        return abs(abs(pitch) - (.pi / 2)) < threshold
    }

    private let motionManager = CMMotionManager()
    @Published var arSession: ARSession?

    // NEW: Display options for UI
    @Published var showDepthMapView: Bool = false
    @Published var showEdgeOverlay: Bool = true

    override init() {
        self.arSession = ARSession()
        super.init()
        arSession?.delegate = self
        startARSession()
        startCoreMotionUpdates()
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
        arSession?.pause()
    }

    // MARK: AR Session Setup
    func startARSession() {
        let configuration = ARWorldTrackingConfiguration()
        // Disable unneeded features
        configuration.isLightEstimationEnabled = false
        configuration.environmentTexturing = .none

        // Only insert depth semantics; disable plane detection
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
            configuration.planeDetection = []
            print("Using ARKit sceneDepth (LiDAR if available).")
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
            configuration.planeDetection = []
            print("Using ARKit smoothedSceneDepth (environment depth).")
        } else {
            print("No AR depth support on this device.")
        }

        arSession?.run(configuration)
        print("AR session started.")
    }
    
    // Call this from CameraView after you create the session, if needed.
    func setSession(_ session: ARSession) {
        self.arSession = session
    }
        
    // Pause the session.
    func pauseSession() {
        DispatchQueue.main.async {
            self.arSession?.pause()
            print("ARSession paused.")
        }
    }
    
    // Resume (or start) the session with the proper configuration.
    func resumeSession() {
        guard let session = self.arSession else { return }
        let config = ARWorldTrackingConfiguration()
        config.isLightEstimationEnabled = false
        config.environmentTexturing = .none

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
            config.planeDetection = []
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
            config.planeDetection = []
        }

        DispatchQueue.main.async {
            session.run(config, options: [.resetTracking, .removeExistingAnchors])
            print("ARSession resumed.")
        }
    }

    // MARK: CoreMotion Updates
    private func startCoreMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device Motion not available.")
            return
        }
        // Throttled at 10 Hz (unchanged, as requested)
        motionManager.deviceMotionUpdateInterval = 1.0 / 5.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            let quat = motion.attitude.quaternion
            let siny_cosp = 2.0 * (quat.w * quat.z + quat.x * quat.y)
            let cosy_cosp = 1.0 - 2.0 * (quat.y * quat.y + quat.z * quat.z)
            let currentYaw = atan2(siny_cosp, cosy_cosp)
            if self.initialYaw == nil { self.initialYaw = currentYaw }
            var normalized = currentYaw - (self.initialYaw ?? 0.0)
            while normalized < 0 { normalized += (2.0 * .pi) }
            while normalized > 2.0 * .pi { normalized -= (2.0 * .pi) }
            self.rotationAngle = Float(normalized * (180.0 / .pi))
            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll
        }
    }

    func resetInitialYaw() {
        guard let motion = motionManager.deviceMotion else {
            print("Could not get current device motion from CoreMotion")
            return
        }
        let q = motion.attitude.quaternion
        let siny_cosp = 2.0 * (q.w * q.z + q.x * q.y)
        let cosy_cosp = 1.0 - 2.0 * (q.y * q.y + q.z * q.z)
        let yaw = atan2(siny_cosp, cosy_cosp)
        initialYaw = yaw
        print("Initial yaw set to \(yaw) (radians).")
    }

    // MARK: ARSessionDelegate Methods
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        autoreleasepool {
            // If you ever move depth reading here instead of CameraView,
            // only read the portion of the depth map you actually need.
        }
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

    // MARK: Edge Detection
    @Published var depthEdgeIndices: [Int] = []
    @Published var depthEdgeThreshold: Float = 0.3
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
    @Published var scalingConstant: Float = 0.0

    func computeDepthEdges() {
        guard let slice = averagedCentralColumnsDepthFloats(colCount: lidarRows) else {
            depthEdgeIndices = []
            edgeDistance = nil
            screenPixelSpanFromEdges = nil
            return
        }

        var candidateEdges: [Int] = []
        for i in 0..<(slice.count - 1) {
            let diff = abs(slice[i + 1] - slice[i])
            if diff > depthEdgeThreshold {
                candidateEdges.append(i)
            }
        }

        var characterizedEdges: [(index: Int, charDepth: Double)] = []
        for i in candidateEdges {
            let leftIndex = max(i - 2, 0)
            let rightIndex = min(i + 2, slice.count - 1)
            let leftDepth = Double(slice[leftIndex])
            let rightDepth = Double(slice[rightIndex])
            let charDepth = min(leftDepth, rightDepth)
            characterizedEdges.append((index: i, charDepth: charDepth))
        }

        let oldEdges = self.depthEdgeIndices
        let filteredCharacterizedEdges = characterizedEdges.filter { $0.charDepth < 1.60 }
        var finalEdges: [Int] = []
        if filteredCharacterizedEdges.count >= 2 {
            let sortedEdges = filteredCharacterizedEdges.sorted { $0.charDepth < $1.charDepth }
            finalEdges = Array(sortedEdges.prefix(2)).map { $0.index }.sorted()
        }

        if finalEdges.count == 2 {
            let diff = abs(finalEdges[1] - finalEdges[0])
            if diff < 3 { finalEdges = oldEdges }
        }

        DispatchQueue.main.async {
            self.depthEdgeIndices = finalEdges
            if finalEdges.count >= 2 {
                let first = finalEdges.first!
                let last = finalEdges.last!
                self.edgeDistance = abs(last - first)
                if let edgeDist = self.edgeDistance, edgeDist > 0 {
                    self.screenPixelSpanFromEdges = CGFloat(edgeDist) *
                        UIScreen.main.bounds.width * 3 / 118.0
                } else {
                    self.screenPixelSpanFromEdges = nil
                }
                // New logic: update centralDepth to be the depth at the midpoint between detected edges.
                let midIndex = (first + last) / 2
                let newCenterDepth = Double(slice[midIndex])
                self.centralDepth = newCenterDepth
                print("Central depth updated from edge midpoint: \(newCenterDepth)")
            } else {
                // If no valid edge pair is detected, centralDepth remains set by CameraView.
                self.edgeDistance = nil
                self.screenPixelSpanFromEdges = nil
            }
        }
    }
    
    @Published var lidarRows: Int = 3
    
    func averagedCentralColumnsDepthFloats(colCount: Int) -> [Float]? {
        guard !fullLiDARFloats.isEmpty, lidarWidth > 0, lidarHeight > 0 else { return nil }
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

    // MARK: Real Width Calculation
    @Published var edgeDistance: Int? {
        didSet { computeRealWidth() }
    }
    var focalLengthPixels: Double? {
        didSet { computeRealWidth() }
    }
    @Published var constant: Double = 0.0
    @Published var usedDepth: Double? = 0.0
    @Published var usedDepthEdgeIndices: [Int] = []

    func computeRealWidth() {
        if let slice = averagedCentralColumnsDepthFloats(colCount: 5),
           depthEdgeIndices.count >= 2 {
            let leftEdge = depthEdgeIndices.first!
            let rightEdge = depthEdgeIndices.last!
            let leftIndex = min(leftEdge + 2, slice.count - 1)
            let rightIndex = max(rightEdge - 2, 0)
            usedDepthEdgeIndices = [leftIndex, rightIndex]
            usedDepth = (Double(slice[leftIndex]) + Double(slice[rightIndex])) / 2.0
        } else {
            usedDepth = centralDepth
        }
        guard let dist = edgeDistance,
              let depthValue = usedDepth,
              let focalColor = focalLengthPixels,
              focalColor > 0,
              colorHeight > 0,
              lidarHeight > 0 else {
            // Fall back to last known realWidth if we can't compute
            if let lastNonZero = realWidthBuffer.reversed().first(where: { $0 != 0 }) {
                realWidth = lastNonZero
            } else {
                realWidth = nil
            }
            return
        }
        let focalLidarY = focalColor * (Double(lidarHeight) / Double(colorHeight))
        let adjustedDist = Double(dist) + constant
        let newWidth = (adjustedDist * depthValue) / focalLidarY
        realWidthBuffer.append(newWidth)
        if realWidthBuffer.count > 3 { realWidthBuffer.removeFirst() }
        let nonZeroValues = realWidthBuffer.filter { $0 != 0 }
        if nonZeroValues.count >= 3 {
            realWidth = nonZeroValues.reduce(0.0, +) / Double(nonZeroValues.count)
        } else {
            realWidth = realWidthBuffer.reversed().first(where: { $0 != 0 })
        }
    }

    func lidarToScreenPoint(col: Int, row: Int) -> CGPoint? {
        guard lidarWidth > 0, lidarHeight > 0 else { return nil }
        let colNormalized = CGFloat(Double(col) + 0.5) / CGFloat(lidarWidth)
        let rowNormalized = CGFloat(Double(row) + 0.5) / CGFloat(lidarHeight)
        let normalizedPt = CGPoint(x: colNormalized, y: rowNormalized)
        return normalizedPt.applying(displayTransform)
    }

    // MARK: Measurement Data Structure
    struct Measurement: Identifiable {
        let id = UUID()
        let timestamp: Date
        let edgeDistance: Int?
        let centralDepth: Double?
        var realWidth: Double?
        var rotationAngle: Float
        var isPlaceholder: Bool = false
        var correctedWidth: Double? = nil
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
                rotationAngle: rotationAngle,
                isPlaceholder: false
            )
            measurements.append(measurement)
        } else {
            let measurement = Measurement(
                timestamp: Date(),
                edgeDistance: nil,
                centralDepth: nil,
                realWidth: nil,
                rotationAngle: rotationAngle,
                isPlaceholder: true
            )
            measurements.append(measurement)
        }
    }

    // MARK: Continuous Save Interval
    @Published var saveInterval: Double = 1.0
    @Published var widthsAreCorrected: Bool = false
    @Published var divider: Double = 2.50

    func applyWidthCorrection() {
        print("Width correction applied!")
        guard let focalColor = focalLengthPixels,
              colorHeight > 0,
              lidarHeight > 0 else {
            print("Insufficient parameters to apply correction.")
            return
        }
        
        let focalLidarY = focalColor * (Double(lidarHeight) / Double(colorHeight))
        let n = measurements.count
        if n < 2 {
            print("Not enough measurements for correction.")
            return
        }
        
        // Backup the original measurement at index 1 for use by the final measurement.
        let backupMeasurementAtIndex1 = measurements[1]
        
        // Calculate the number of indices to move to get a 90° offset.
        let step = (n - 1) / 4
        
        for i in 0..<n {
            var meas = measurements[i]
            guard let edgeDist = meas.edgeDistance,
                  let zCentral = meas.centralDepth,
                  let _ = meas.realWidth else { continue }
            let edgeDistancePixels = Double(edgeDist)
            
            // Determine the target index for a measurement 90° ahead.
            let targetIndex: Int = (i == n - 1) ? 1 : (i + step) % n
            let targetMeas: Measurement = (i == n - 1) ? backupMeasurementAtIndex1 : measurements[targetIndex]
            guard let width90 = targetMeas.realWidth else { continue }
            
            let corrected = (edgeDistancePixels * (zCentral + (width90 / divider))) / focalLidarY
            meas.correctedWidth = corrected
            meas.realWidth = corrected
            measurements[i] = meas
            
            print("Measurement \(i): target index \(targetIndex), focalLidarY: \(focalLidarY), zCentral: \(zCentral), edgeDistancePixels: \(edgeDistancePixels), width90: \(width90)")
        }
        
        widthsAreCorrected = true
        print("Applied width correction to measurements.")
    }
    
    // Clothing correction property and function.
    @Published var clothingWidth: Double = 1.0

    func applyClothingCorrection() {
        for i in measurements.indices {
            if let currentWidth = measurements[i].realWidth {
                let corrected = max(currentWidth - clothingWidth/100, 0)
                measurements[i].realWidth = corrected
                measurements[i].correctedWidth = corrected
            }
        }
        print("Applied clothing correction with constant \(clothingWidth) cm to all measurements.")
    }

    func useSymmetry() {
        guard measurements.count % 2 == 1 else {
            print("Symmetry can only be applied when there is an odd number of measurements.")
            return
        }
        let n = measurements.count
        let mid = n / 2
        let threshold = 1.0
        for i in 0..<mid {
            let j = n - 1 - i
            if let valueI = measurements[i].realWidth, let valueJ = measurements[j].realWidth {
                if abs(valueI - valueJ) <= threshold {
                    let avg = (valueI + valueJ) / 2.0
                    measurements[i].realWidth = avg
                    measurements[j].realWidth = avg
                }
            }
        }
        if let first = measurements.first?.realWidth,
           let middle = measurements[mid].realWidth,
           let last = measurements.last?.realWidth {
            if abs(first - middle) <= threshold && abs(middle - last) <= threshold {
                let avg = (first + middle + last) / 3.0
                measurements[0].realWidth = avg
                measurements[mid].realWidth = avg
                measurements[n - 1].realWidth = avg
            }
        }
        if n >= 7 {
            let indexA = 2
            let indexB = n - 3
            if let valueA = measurements[indexA].realWidth, let valueB = measurements[indexB].realWidth {
                if abs(valueA - valueB) <= threshold {
                    let avg = (valueA + valueB) / 2.0
                    measurements[indexA].realWidth = avg
                    measurements[indexB].realWidth = avg
                }
            }
        }
        measurements = measurements
        print("Applied symmetry adjustments to measurements.")
    }
}

extension ARModel {
    /// Computes the Simpson maximum derivative based on the min and max measured widths.
    /// Assumes a sinusoidal behavior: f(θ) ≈ offset + A*cos(2θ),
    /// so that simpsonMaxDeriv = max|f⁽⁴⁾(θ)+f⁽⁶⁾(θ)| = 48 * A.
    func updateSimpsonMaxDeriv() {
        let widths = measurements.compactMap { $0.realWidth }
        guard let minW = widths.min(), let maxW = widths.max() else {
            simpsonMaxDeriv = 0
            return
        }
        let amplitude = (maxW - minW) / 2.0
        simpsonMaxDeriv = 48 * amplitude
        print("Updated simpsonMaxDeriv to \(simpsonMaxDeriv) based on amplitude \(amplitude)")
    }
}
