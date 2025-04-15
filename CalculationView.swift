//import SwiftUI
//import Charts
//
//enum CalculationMode {
//    case full
//    case twoPoint
//    case circular
//}
//
//struct CalculationView: View {
//    @ObservedObject var arModel: ARModel
//    let mode: CalculationMode
//
//    // MARK: - Helper Functions
//    
//    // Compute average real width (in meters) from non-placeholder measurements.
//    private func averageRealWidth() -> Double? {
//        let widths = arModel.measurements.compactMap { $0.realWidth }
//        return widths.isEmpty ? nil : widths.reduce(0, +) / Double(widths.count)
//    }
//    
//    // Compute average depth (in meters) from measurements.
//    private func averageDepth() -> Double? {
//        let depths = arModel.measurements.compactMap { $0.centralDepth }
//        return depths.isEmpty ? nil : depths.reduce(0, +) / Double(depths.count)
//    }
//    
//    // Compute average edge distance (in pixels) from measurements.
//    private func averageEdgeDistance() -> Double? {
//        let edges = arModel.measurements.compactMap { measurement -> Double? in
//            if let edge = measurement.edgeDistance {
//                return Double(edge)
//            }
//            return nil
//        }
//        return edges.isEmpty ? nil : edges.reduce(0, +) / Double(edges.count)
//    }
//    
//    // Compute circumference based on the selected mode.
//    private func computeCircumference() -> Double {
//        switch mode {
//        case .full:
//            return computeCircumferenceFull()
//        case .twoPoint:
//            return computeCircumferenceTwoPoint()
//        case .circular:
//            return computeCircumferenceCircular()
//        }
//    }
//    
//    // MARK: - Circumference Error Calculation (Measurement & Correction Only)
//    //
//    // This function now only considers the error due to:
//    //   • LiDAR noise (using a combined uncertainty of 0.01118 m for Z)
//    //   • Pixel count error (±5 pixels)
//    //   • Reduction of error by averaging symmetric measurements
//    //   • The correction step that updates Z (which amplifies the error)
//    //
//    // We first compute the relative error from a single measurement (in quadrature),
//    // then reduce it by the square root of the effective number of independent (symmetric) pairs.
//    // Finally, we account for the correction step by dividing by:
//    //   1 - (0.25 * C)/avgDepth.
//    private func computeCircumferenceError(circumference C: Double) -> Double {
//        // Use only non-placeholder measurements.
//        let validCount = arModel.measurements.filter { !$0.isPlaceholder }.count
//        if validCount == 0 { return 0.0 }
//        
//        // Determine effective independent measurement pairs (symmetry averaging).
//        let effectiveCount = (validCount % 2 == 0) ? validCount / 2 : (validCount + 1) / 2
//        
//        // Ensure required averages are available.
//        guard let avgDepth = averageDepth(), avgDepth != 0,
//              let avgEdgeDistance = averageEdgeDistance(), avgEdgeDistance > 0 else {
//            return 0.0
//        }
//        
//        // Relative error contributions:
//        // LiDAR (using combined Z error 0.01118 m) and pixel error (±5 pixels).
//        let epsZ = 0.01118 / avgDepth
//        let epsW = 5.0 / avgEdgeDistance
//        
//        // For one measurement, the relative error (combined in quadrature):
//        let relErrorSingle = sqrt(pow(epsZ, 2) + pow(epsW, 2))
//        // Averaging symmetric pairs reduces error by sqrt(2):
//        let relErrorPair = relErrorSingle / sqrt(2.0)
//        // Averaging over all independent pairs:
//        let measurementRelError = relErrorPair / sqrt(Double(effectiveCount))
//        
//        // Correction step:
//        // Our correction adds half the measured width to Z, which introduces an additional
//        // error that we model as amplifying the measurement error by a factor:
//        let denominator = 1 - (0.25 * C) / avgDepth
//        if denominator <= 0 {
//            return 0.0
//        }
//        
//        let totalRelError = measurementRelError / denominator
//        let absoluteError = C * totalRelError
//        return absoluteError
//    }
//    
//    // MARK: - Error Breakdown for Pie Chart
//    //
//    // This computed property breaks down the overall relative error into:
//    // - The measurement error portion from LiDAR and pixel noise (averaged over symmetric pairs)
//    // - The additional error introduced by the correction step.
//    //
//    // We compute:
//    //   E_meas = sqrt(epsZ² + epsW²) / sqrt(2 * N_eff)
//    //   E_total = E_meas / (1 - (0.25 * C)/avgDepth)
//    //
//    // The variance (squared error) due to correction is: E_total² - E_meas².
//    // Then the percentage contributions are:
//    //   • LiDAR: fraction of measurement variance due to epsZ.
//    //   • Pixel: fraction of measurement variance due to epsW.
//    //   • Correction: the additional variance from the correction step.
//    private var errorBreakdownData: [(label: String, value: Double)] {
//        // Use only non-placeholder measurements.
//        let validCount = arModel.measurements.filter { !$0.isPlaceholder }.count
//        guard validCount > 0,
//              let avgDepth = averageDepth(), avgDepth != 0,
//              let avgEdgeDistance = averageEdgeDistance(), avgEdgeDistance > 0 else {
//            return []
//        }
//        
//        let C = computeCircumference()
//        let effectiveCount = (validCount % 2 == 0) ? validCount / 2 : (validCount + 1) / 2
//        
//        let epsZ = 0.01118 / avgDepth
//        let epsW = 5.0 / avgEdgeDistance
//        
//        // Measurement relative error for one symmetric pair:
//        let E_meas = sqrt(pow(epsZ, 2) + pow(epsW, 2)) / sqrt(2.0 * Double(effectiveCount))
//        
//        let denominator = 1 - (0.25 * C) / avgDepth
//        if denominator <= 0 { return [] }
//        let E_total = E_meas / denominator
//        
//        // The measurement variance (before correction) is E_meas²;
//        // the correction adds extra variance: E_total² - E_meas².
//        let pctCorrection = (1 - pow(denominator, 2)) * 100.0  // correction contribution percentage
//        // The measurement component contributes the remaining percentage:
//        let pctMeasurement = pow(denominator, 2) * 100.0
//        
//        // Within the measurement error, the fraction from LiDAR and Pixel are:
//        let totalEpsSq = pow(epsZ, 2) + pow(epsW, 2)
//        let pctLiDAR = totalEpsSq > 0 ? (pow(epsZ, 2) / totalEpsSq) * pctMeasurement : 0.0
//        let pctPixel = totalEpsSq > 0 ? (pow(epsW, 2) / totalEpsSq) * pctMeasurement : 0.0
//        
//        return [
//            ("LiDAR", pctLiDAR),
//            ("Pixel", pctPixel),
//            ("Correction", pctCorrection)
//        ]
//    }
//    
//    // MARK: - Circumference Calculation Functions
//    
//    private func computeCircumferenceFull() -> Double {
//        let ms = arModel.measurements
//        if ms.count < 3 { return 0 }
//        var widths: [Double] = []
//        var angles: [Double] = []
//        for m in ms {
//            if let w = m.realWidth, !m.isPlaceholder {
//                widths.append(w)
//                angles.append(Double(m.rotationAngle))
//            }
//        }
//        return integratedCircumference(widths: widths, anglesDegrees: angles)
//    }
//    
//    private func computeCircumferenceTwoPoint() -> Double {
//        let ms = arModel.measurements
//        if ms.count != 2 { return 0 }
//        let x = ms[0].realWidth ?? 0
//        let y = ms[1].realWidth ?? 0
//        let widths = [x, y, x, y, x]
//        let angles = [0.0, 90.0, 180.0, 270.0, 360.0]
//        return integratedCircumference(widths: widths, anglesDegrees: angles)
//    }
//    
//    private func computeCircumferenceCircular() -> Double {
//        let ms = arModel.measurements
//        if ms.count != 1 { return 0 }
//        return .pi * (ms[0].realWidth ?? 0)
//    }
//    
//    // Integrated circumference via Simpson’s rule.
//    private func integratedCircumference(widths: [Double], anglesDegrees: [Double]) -> Double {
//        let combined = zip(anglesDegrees, widths).sorted { $0.0 < $1.0 }
//        var sortedAngles = combined.map { $0.0 }
//        var sortedWidths = combined.map { $0.1 }
//        
//        // Reorder so that the largest width is first, and ensure cyclic continuity.
//        if let maxVal = sortedWidths.max(),
//           let idx = sortedWidths.firstIndex(of: maxVal),
//           sortedWidths.count > 1 {
//            if idx != 0 {
//                let head = Array(sortedWidths[idx...])
//                let tail = Array(sortedWidths[..<idx])
//                sortedWidths = head + tail
//            }
//            if sortedWidths.last != sortedWidths.first {
//                sortedWidths.append(sortedWidths.first!)
//            }
//        }
//        
//        let thetaRads = sortedAngles.map { $0 * .pi / 180.0 }
//        guard thetaRads.count >= 3 else { return 0 }
//        
//        let deltaTheta = thetaRads[1] - thetaRads[0]
//        if deltaTheta <= 0 { return 0 }
//        
//        let uniqueWidths = Array(sortedWidths.dropLast())
//        let d2w = cyclicSecondDerivative(uniqueWidths, dx: deltaTheta)
//        
//        // Build the integrand: width + second derivative.
//        var integrand: [Double] = []
//        for i in 0..<uniqueWidths.count {
//            integrand.append(uniqueWidths[i] + d2w[i])
//        }
//        
//        return simpson(integrand, dx: deltaTheta)
//    }
//    
//    private func cyclicSecondDerivative(_ y: [Double], dx: Double) -> [Double] {
//        let n = y.count
//        var d2 = [Double](repeating: 0, count: n)
//        for i in 0..<n {
//            let next = (i + 1) % n
//            let prev = (i - 1 + n) % n
//            d2[i] = (y[next] - 2 * y[i] + y[prev]) / (dx * dx)
//        }
//        return d2
//    }
//    
//    private func simpson(_ y: [Double], dx: Double) -> Double {
//        let n = y.count
//        if n < 2 { return 0 }
//        
//        let intervals = n - 1
//        var sum = 0.0
//        
//        if intervals % 2 == 0 {
//            var i = 0
//            while i < intervals {
//                let y0 = y[i]
//                let y1 = y[i + 1]
//                let y2 = y[i + 2]
//                sum += (dx / 6.0) * (y0 + 4.0 * y1 + y2)
//                i += 2
//            }
//        } else {
//            var i = 0
//            while i < (intervals - 1) {
//                let y0 = y[i]
//                let y1 = y[i + 1]
//                let y2 = y[i + 2]
//                sum += (dx / 6.0) * (y0 + 4.0 * y1 + y2)
//                i += 2
//            }
//            let yA = y[n - 2]
//            let yB = y[n - 1]
//            sum += 0.5 * dx * (yA + yB)
//        }
//        
//        return sum
//    }
//    
//    // MARK: - Chart Data for Line Chart
//    
//    private var plotData: [(angle: Double, width: Double)] {
//        let sorted = arModel.measurements.sorted { $0.rotationAngle < $1.rotationAngle }
//        var data: [(Double, Double)] = []
//        for (i, m) in sorted.enumerated() {
//            let angleRad = Double(m.rotationAngle) * .pi / 180.0
//            if let w = m.realWidth, !m.isPlaceholder {
//                data.append((angleRad, w))
//            } else if m.isPlaceholder, let interp = interpolatedWidth(for: i, in: sorted) {
//                data.append((angleRad, interp))
//            }
//        }
//        return data
//    }
//    
//    private func interpolatedWidth(for index: Int, in measurements: [ARModel.Measurement]) -> Double? {
//        guard measurements[index].isPlaceholder == true else {
//            return measurements[index].realWidth
//        }
//        var prevIndex: Int? = nil
//        for i in stride(from: index - 1, through: 0, by: -1) {
//            if !measurements[i].isPlaceholder, measurements[i].realWidth != nil {
//                prevIndex = i
//                break
//            }
//        }
//        var nextIndex: Int? = nil
//        for i in (index + 1)..<measurements.count {
//            if !measurements[i].isPlaceholder, measurements[i].realWidth != nil {
//                nextIndex = i
//                break
//            }
//        }
//        if let prev = prevIndex, let next = nextIndex,
//           let prevWidth = measurements[prev].realWidth,
//           let nextWidth = measurements[next].realWidth {
//            let factor = Double(index - prev) / Double(next - prev)
//            return prevWidth + factor * (nextWidth - prevWidth)
//        }
//        return nil
//    }
//    
//    // MARK: - Body
//    
//    var body: some View {
//        // Compute circumference and its error.
//        let circumference = computeCircumference()
//        let error = computeCircumferenceError(circumference: circumference)
//        
//        ScrollView {
//            VStack(spacing: 16) {
//                Spacer(minLength: 16)
//                
//                Text("Approx. Result:")
//                    .font(.headline)
//                
//                // Display circumference and error in centimeters.
//                Text(String(format: "%.2f cm ± %.2f cm", circumference * 100, error * 100))
//                    .font(.largeTitle)
//                    .bold()
//                    .padding(.horizontal)
//                
//                // Line Chart: Width vs. Angle.
//                Chart {
//                    ForEach(plotData, id: \.angle) { point in
//                        LineMark(
//                            x: .value("Angle (rad)", point.angle),
//                            y: .value("Width (m)", point.width)
//                        )
//                        PointMark(
//                            x: .value("Angle (rad)", point.angle),
//                            y: .value("Width (m)", point.width)
//                        )
//                    }
//                }
//                .frame(height: 250)
//                .padding()
//                .chartXAxis {
//                    AxisMarks(values: .stride(by: Double.pi/2)) { value in
//                        AxisGridLine()
//                        AxisTick()
//                        if let doubleValue = value.as(Double.self) {
//                            AxisValueLabel(String(format: "%.2f", doubleValue))
//                        }
//                    }
//                }
//                
//                // Pie Chart: Error Breakdown.
//                Chart {
//                    ForEach(errorBreakdownData, id: \.label) { data in
//                        SectorMark(
//                            angle: .value("Error %", data.value),
//                            innerRadius: .ratio(0.3)
//                        )
//                        .foregroundStyle(by: .value("Component", data.label))
//                    }
//                }
//                .frame(height: 300)
//                .padding()
//                
//                Spacer(minLength: 16)
//            }
//        }
//        .navigationTitle("Circumference Calc")
//        // Update simpsonMaxDeriv asynchronously when measurements change.
//        .onReceive(arModel.$measurements) { _ in
//            DispatchQueue.main.async {
//                arModel.updateSimpsonMaxDeriv()
//            }
//        }
//    }
//}
//
//struct CalculationView_Previews: PreviewProvider {
//    static var previews: some View {
//        // Use a mock ARModel for preview purposes.
//        CalculationView(arModel: ARModel(), mode: .full)
//    }
//}

import SwiftUI
import Charts

enum CalculationMode {
    case full
    case twoPoint
    case circular
}

struct CalculationView: View {
    @ObservedObject var arModel: ARModel
    let mode: CalculationMode

    // MARK: - Helper Functions
    
    // Compute average real width (in meters) from non-placeholder measurements.
    private func averageRealWidth() -> Double? {
        let widths = arModel.measurements.compactMap { $0.realWidth }
        return widths.isEmpty ? nil : widths.reduce(0, +) / Double(widths.count)
    }
    
    // Compute average depth (in meters) from measurements.
    private func averageDepth() -> Double? {
        let depths = arModel.measurements.compactMap { $0.centralDepth }
        return depths.isEmpty ? nil : depths.reduce(0, +) / Double(depths.count)
    }
    
    // Compute average edge distance (in pixels) from measurements.
    private func averageEdgeDistance() -> Double? {
        let edges = arModel.measurements.compactMap { measurement -> Double? in
            if let edge = measurement.edgeDistance {
                return Double(edge)
            }
            return nil
        }
        return edges.isEmpty ? nil : edges.reduce(0, +) / Double(edges.count)
    }
    
    // Compute circumference based on the selected mode.
    private func computeCircumference() -> Double {
        switch mode {
        case .full:
            return computeCircumferenceFull()
        case .twoPoint:
            return computeCircumferenceTwoPoint()
        case .circular:
            return computeCircumferenceCircular()
        }
    }
    
    // MARK: - Circumference Error Calculation (Measurement & Correction Only)
    private func computeCircumferenceError(circumference C: Double) -> Double {
        // Use only non-placeholder measurements.
        let validCount = arModel.measurements.filter { !$0.isPlaceholder }.count
        if validCount == 0 { return 0.0 }
        
        // Determine effective independent measurement pairs (symmetry averaging).
        let effectiveCount = (validCount % 2 == 0) ? validCount / 2 : (validCount + 1) / 2
        
        // Ensure required averages are available.
        guard let avgDepth = averageDepth(), avgDepth != 0,
              let avgEdgeDistance = averageEdgeDistance(), avgEdgeDistance > 0 else {
            return 0.0
        }
        
        // Relative error contributions.
        let epsZ = 0.01118 / avgDepth
        let epsW = 2.5 / avgEdgeDistance
        let relErrorSingle = sqrt(pow(epsZ, 2) + pow(epsW, 2))
        let relErrorPair = relErrorSingle / sqrt(2.0)
        let measurementRelError = relErrorPair / sqrt(Double(effectiveCount))
        
        let denominator = 1 - (0.25 * C) / avgDepth
        if denominator <= 0 {
            return 0.0
        }
        
        let totalRelError = measurementRelError / denominator
        var absoluteError = C * totalRelError
        let noiseStdDev = sqrt(arModel.variance)
        let resultingStdDev = (3.57 * noiseStdDev) + 0.02
        absoluteError = absoluteError + resultingStdDev/100
        return absoluteError * 0.7 //average case error
    }
    
    // MARK: - Error Breakdown for Pie Chart
    private var errorBreakdownData: [(label: String, value: Double)] {
        // Ensure required averages and valid measurements.
        let validMeasurements = arModel.measurements.filter { !$0.isPlaceholder }
        guard validMeasurements.count > 0,
              let avgDepth = averageDepth(), avgDepth != 0,
              let avgEdgeDistance = averageEdgeDistance(), avgEdgeDistance > 0 else {
            return []
        }
        
        // Effective (symmetric) measurement count.
        let effectiveCount = (validMeasurements.count % 2 == 0)
            ? validMeasurements.count / 2
            : (validMeasurements.count + 1) / 2
        
        let C = computeCircumference()  // Circumference in meters.
        
        // Use the same EPS values as in computeCircumferenceError.
        let epsZ = 0.01118 / avgDepth
        // Note: In computeCircumferenceError you use 2.5 for pixel error;
        // here we use the same value for consistency.
        let epsW = 2.5 / avgEdgeDistance
        
        // Baseline (uncorrected) measurement relative error.
        let E_meas = sqrt(pow(epsZ, 2) + pow(epsW, 2)) / sqrt(2.0 * Double(effectiveCount))
        
        // Apply the correction factor.
        let denom = 1 - (0.25 * C) / avgDepth
        if denom <= 0 { return [] }
        
        // Measurement error contributions.
        // Uncorrected measurement error (in meters).
        let measError_uncorrected = C * E_meas
        // Corrected measurement error (in meters).
        let measError_corrected = C * (E_meas / denom)
        
        // The correction adds the difference between corrected and uncorrected error.
        let correctionError = measError_corrected - measError_uncorrected
        
        // Now break the uncorrected measurement error into LiDAR and Pixel components,
        // proportionally to the variance contributions.
        let totalEpsSq = pow(epsZ, 2) + pow(epsW, 2)
        let lidarError_uncorrected = measError_uncorrected * (totalEpsSq > 0 ? (pow(epsZ, 2) / totalEpsSq) : 0)
        let pixelError_uncorrected = measError_uncorrected * (totalEpsSq > 0 ? (pow(epsW, 2) / totalEpsSq) : 0)
        
        // We now want to report the final (corrected) measurement contributions.
        // One common approach is to leave the LiDAR and Pixel contributions as the uncorrected
        // baseline (since the correction is treated separately).
        // Edge detector error: computed from the AR model’s variance.
        let noiseStdDev = sqrt(arModel.variance)       // in centimeters already (for UI display)
        let edgeError_cm = (3.57 * noiseStdDev + 0.02)   // in centimeters
        
        // Apply the overall scale factor (from computeCircumferenceError) uniformly.
        let scale = 0.7
        
        // Convert measurement contributions (which are in meters) to centimeters.
        let lidarError_cm = lidarError_uncorrected * scale * 100
        let pixelError_cm = pixelError_uncorrected * scale * 100
        let correctionError_cm = correctionError * scale * 100
        
        // Total error (for verification) would be:
        //   Total_meas = measError_corrected * scale * 100   (measurement part, in cm)
        //   Total_error = Total_meas + edgeError_cm
        
        return [
            ("LiDAR", lidarError_cm),
            ("Pixel", pixelError_cm),
            ("Correction", correctionError_cm),
            ("Edge detector", edgeError_cm * scale) // apply scale if you want it consistent
        ]
    }
    // MARK: - Circumference Calculation Functions
    private func computeCircumferenceFull() -> Double {
        let ms = arModel.measurements
        if ms.count < 3 { return 0 }
        var widths: [Double] = []
        var angles: [Double] = []
        for m in ms {
            if let w = m.realWidth, !m.isPlaceholder {
                widths.append(w)
                angles.append(Double(m.rotationAngle))
            }
        }
        return integratedCircumference(widths: widths, anglesDegrees: angles)
    }
    
    private func computeCircumferenceTwoPoint() -> Double {
        let ms = arModel.measurements
        if ms.count != 2 { return 0 }
        let x = ms[0].realWidth ?? 0
        let y = ms[1].realWidth ?? 0
        let widths = [x, y, x, y, x]
        let angles = [0.0, 90.0, 180.0, 270.0, 360.0]
        return integratedCircumference(widths: widths, anglesDegrees: angles)
    }
    
    private func computeCircumferenceCircular() -> Double {
        let ms = arModel.measurements
        if ms.count != 1 { return 0 }
        return .pi * (ms[0].realWidth ?? 0)
    }
    
    // Integrated circumference via Simpson’s rule.
    private func integratedCircumference(widths: [Double], anglesDegrees: [Double]) -> Double {
        let combined = zip(anglesDegrees, widths).sorted { $0.0 < $1.0 }
        var sortedAngles = combined.map { $0.0 }
        var sortedWidths = combined.map { $0.1 }
        
        if let maxVal = sortedWidths.max(),
           let idx = sortedWidths.firstIndex(of: maxVal),
           sortedWidths.count > 1 {
            if idx != 0 {
                let head = Array(sortedWidths[idx...])
                let tail = Array(sortedWidths[..<idx])
                sortedWidths = head + tail
            }
            if sortedWidths.last != sortedWidths.first {
                sortedWidths.append(sortedWidths.first!)
            }
        }
        
        let thetaRads = sortedAngles.map { $0 * .pi / 180.0 }
        guard thetaRads.count >= 3 else { return 0 }
        
        let deltaTheta = thetaRads[1] - thetaRads[0]
        if deltaTheta <= 0 { return 0 }
        
        let uniqueWidths = Array(sortedWidths.dropLast())
        let d2w = cyclicSecondDerivative(uniqueWidths, dx: deltaTheta)
        
        var integrand: [Double] = []
        for i in 0..<uniqueWidths.count {
            integrand.append(uniqueWidths[i] + d2w[i])
        }
        
        return simpson(integrand, dx: deltaTheta)
    }
    
    private func cyclicSecondDerivative(_ y: [Double], dx: Double) -> [Double] {
        let n = y.count
        var d2 = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let next = (i + 1) % n
            let prev = (i - 1 + n) % n
            d2[i] = (y[next] - 2 * y[i] + y[prev]) / (dx * dx)
        }
        return d2
    }
    
    private func simpson(_ y: [Double], dx: Double) -> Double {
        let n = y.count
        if n < 2 { return 0 }
        
        let intervals = n - 1
        var sum = 0.0
        
        if intervals % 2 == 0 {
            var i = 0
            while i < intervals {
                let y0 = y[i]
                let y1 = y[i + 1]
                let y2 = y[i + 2]
                sum += (dx / 6.0) * (y0 + 4.0 * y1 + y2)
                i += 2
            }
        } else {
            var i = 0
            while i < (intervals - 1) {
                let y0 = y[i]
                let y1 = y[i + 1]
                let y2 = y[i + 2]
                sum += (dx / 6.0) * (y0 + 4.0 * y1 + y2)
                i += 2
            }
            let yA = y[n - 2]
            let yB = y[n - 1]
            sum += 0.5 * dx * (yA + yB)
        }
        
        return sum
    }
    
    // MARK: - Chart Data for Line Chart
    private var plotData: [(angle: Double, width: Double)] {
        let sorted = arModel.measurements.sorted { $0.rotationAngle < $1.rotationAngle }
        var data: [(Double, Double)] = []
        for (i, m) in sorted.enumerated() {
            let angleRad = Double(m.rotationAngle) * .pi / 180.0
            if let w = m.realWidth, !m.isPlaceholder {
                data.append((angleRad, w))
            } else if m.isPlaceholder, let interp = interpolatedWidth(for: i, in: sorted) {
                data.append((angleRad, interp))
            }
        }
        return data
    }
    
    private func interpolatedWidth(for index: Int, in measurements: [ARModel.Measurement]) -> Double? {
        guard measurements[index].isPlaceholder == true else {
            return measurements[index].realWidth
        }
        var prevIndex: Int? = nil
        for i in stride(from: index - 1, through: 0, by: -1) {
            if !measurements[i].isPlaceholder, measurements[i].realWidth != nil {
                prevIndex = i
                break
            }
        }
        var nextIndex: Int? = nil
        for i in (index + 1)..<measurements.count {
            if !measurements[i].isPlaceholder, measurements[i].realWidth != nil {
                nextIndex = i
                break
            }
        }
        if let prev = prevIndex, let next = nextIndex,
           let prevWidth = measurements[prev].realWidth,
           let nextWidth = measurements[next].realWidth {
            let factor = Double(index - prev) / Double(next - prev)
            return prevWidth + factor * (nextWidth - prevWidth)
        }
        return nil
    }
    
    // MARK: - Body
    var body: some View {
        let circumference = computeCircumference()
        let error = computeCircumferenceError(circumference: circumference)
        
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 16)
                
                Text("Approx. Result:")
                    .font(.headline)
                
                Text(String(format: "%.2f cm ± %.2f cm", circumference * 100, error * 100))
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal)
                
                // New display for variance (if computed).
            
                if arModel.variance > 0 {
                    Text(String(format: "Measurement noise: %.4f cm", sqrt(arModel.variance)))
                        .font(.headline)
                        .padding(.horizontal)
                }
                
                // Line Chart: Width vs. Angle.
                Chart {
                    ForEach(plotData, id: \.angle) { point in
                        LineMark(
                            x: .value("Angle (rad)", point.angle),
                            y: .value("Width (m)", point.width)
                        )
                        PointMark(
                            x: .value("Angle (rad)", point.angle),
                            y: .value("Width (m)", point.width)
                        )
                    }
                }
                .frame(height: 250)
                .padding()
                .chartXAxis {
                    AxisMarks(values: .stride(by: Double.pi/2)) { value in
                        AxisGridLine()
                        AxisTick()
                        if let doubleValue = value.as(Double.self) {
                            AxisValueLabel(String(format: "%.2f", doubleValue))
                        }
                    }
                }
                
                // Pie Chart: Error Breakdown.
                Chart {
                    ForEach(errorBreakdownData, id: \.label) { data in
                        SectorMark(
                            angle: .value("Error Value", data.value),
                            innerRadius: .ratio(0.3)
                        )
                        .foregroundStyle(by: .value("Component", data.label))
                        // Overlay a text label on the slice:
                        .annotation(position: .overlay) {
                            Text(String(format: "%.2f", data.value))
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                        }
                    }
                }
                .frame(height: 250)
                .padding()
                
                Spacer(minLength: 16)
            }
        }
        .navigationTitle("Circumference Calc")
        .onReceive(arModel.$measurements) { _ in
            DispatchQueue.main.async {
                arModel.updateSimpsonMaxDeriv()
            }
        }
    }
}

struct CalculationView_Previews: PreviewProvider {
    static var previews: some View {
        CalculationView(arModel: ARModel(), mode: .full)
    }
}
