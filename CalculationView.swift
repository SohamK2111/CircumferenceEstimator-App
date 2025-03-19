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

    // Helper: Compute average real width (in meters) from non-placeholder measurements.
    private func averageRealWidth() -> Double? {
        let widths = arModel.measurements.compactMap { $0.realWidth }
        return widths.isEmpty ? nil : widths.reduce(0, +) / Double(widths.count)
    }
    
    // Helper: Compute average depth (in meters) from measurements.
    private func averageDepth() -> Double? {
        let depths = arModel.measurements.compactMap { $0.centralDepth }
        return depths.isEmpty ? nil : depths.reduce(0, +) / Double(depths.count)
    }
    
    // Helper: Compute average edge distance (in pixels) from measurements.
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
    
    // Compute the overall error for the circumference measurement.
//    private func computeCircumferenceError(circumference C: Double) -> Double {
//        // Use only non-placeholder measurements for n.
//        let validCount = arModel.measurements.filter { !$0.isPlaceholder }.count
//        let n = max(validCount, 1)
//        
//        // Guard against missing values.
//        guard let avgW = averageRealWidth(), avgW != 0,
//              let avgDepth = averageDepth(), avgDepth != 0,
//              let avgEdgeDistance = averageEdgeDistance(), avgEdgeDistance > 0 else {
//            return 0.0
//        }
//        
//        // Relative error from depth measurement (±3 cm, i.e. 0.03 m).
//        let epsZ = 0.01 / avgDepth
//        
//        // Relative error from width pixel error (±10 pixels).
//        let epsW = 10.0 / avgEdgeDistance
//        
//        // Relative error from Z-correction: the correction term is roughly half the average width.
////        let epsZcorr = (avgW / 2) / avgDepth
//        let epsZcorr = 0.0
//        
//        // Combine the "random" errors (assumed to be independent, hence reduced by sqrt(n))
//        let randomRelError = (epsZ + epsW + epsZcorr) / sqrt(Double(n))
//        
//        // Simpson integration error (systematic): convert absolute Simpson error to a relative error.
//        // (Do not update simpsonMaxDeriv here.)
//        let simpsonRelError: Double = (C != 0) ? (0.01328 * arModel.simpsonMaxDeriv) / C : 0
//        
//        // Total relative error.
//        let totalRelError = randomRelError + simpsonRelError
//        
//        // Overall absolute error in the circumference.
//        let absoluteError = C * totalRelError
//        return absoluteError
//    }
    
    private func computeCircumferenceError(circumference C: Double) -> Double {
        // Count only valid (non-placeholder) measurements.
        let validCount = arModel.measurements.filter { !$0.isPlaceholder }.count
        let n = max(validCount, 1)
        
        // Guard against missing or zero values.
        guard let avgW = averageRealWidth(), avgW != 0,
              let avgDepth = averageDepth(), avgDepth != 0,
              let avgEdgeDistance = averageEdgeDistance(), avgEdgeDistance > 0 else {
            return 0.0
        }
        
        // Relative error from the depth measurement (for example, ±0.01 m uncertainty).
        let epsZ = 0.01 / avgDepth
        
        // Relative error from the width pixel error (e.g. ±10 pixels).
        let epsW = 5.0 / avgEdgeDistance
        
        // Simpson integration relative error remains as before.
        let simpsonRelError: Double = (C != 0) ? (0.01328 * arModel.simpsonMaxDeriv) / C : 0
        
        // In the Z-correction step we add an offset of estimatedWidth/2 to Z.
        // Because that estimated width itself has uncertainty, we assume that
        // its contribution to the relative error is (0.25 * X)/avgDepth,
        // where X is the absolute error in the circumference.
        //
        // In other words, our total relative error (excluding the feedback)
        // is ((epsZ + epsW)/sqrt(n) + simpsonRelError), but then there is an
        // extra term proportional to X. Writing X explicitly:
        //
        //    X = C * [ (epsZ + epsW)/sqrt(n) + simpsonRelError + (0.25 * X)/avgDepth ]
        //
        // Solving for X gives:
        let denominator = 1 - (0.25 * C) / avgDepth
        if denominator <= 0 {
            // If the correction factor becomes nonphysical, return 0 or handle appropriately.
            return 0.0
        }
        
        let totalRelErrorWithoutFeedback = ((epsZ + epsW) / sqrt(Double(n))) + simpsonRelError
        let absoluteError = C * totalRelErrorWithoutFeedback / denominator
        return absoluteError
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
        
        // Reorder so that the largest width is first, and ensure cyclic continuity.
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
        let dw = cyclicGradient(uniqueWidths, dx: deltaTheta)
        let d2w = cyclicSecondDerivative(uniqueWidths, dx: deltaTheta)
        
        // Build the integrand: width + second derivative.
        var integrand: [Double] = []
        for i in 0..<uniqueWidths.count {
            integrand.append(uniqueWidths[i] + d2w[i])
        }
        
        return simpson(integrand, dx: deltaTheta)
    }
    
    private func cyclicGradient(_ y: [Double], dx: Double) -> [Double] {
        let n = y.count
        var g = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let next = (i + 1) % n
            let prev = (i - 1 + n) % n
            g[i] = (y[next] - y[prev]) / (2 * dx)
        }
        return g
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
    
    // MARK: - Plot Data for Chart
    
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
            if !measurements[i].isPlaceholder, let _ = measurements[i].realWidth {
                prevIndex = i
                break
            }
        }
        var nextIndex: Int? = nil
        for i in (index + 1)..<measurements.count {
            if !measurements[i].isPlaceholder, let _ = measurements[i].realWidth {
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
        // Compute circumference and its error.
        let circumference = computeCircumference()
        let error = computeCircumferenceError(circumference: circumference)
        
        VStack(spacing: 16) {
            Spacer()
            
            Text("Approx. Result:")
                .font(.headline)
            
            // Display circumference and error in centimeters (multiply by 100).
            Text(String(format: "%.2f cm ± %.2f cm", circumference * 100, error * 100))
                .font(.largeTitle)
                .bold()
                .padding(.horizontal)
            
            // (Optional) Your Chart view and additional UI...
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
            
            Spacer()
        }
        .navigationTitle("Circumference Calc")
        // Update simpsonMaxDeriv asynchronously when measurements change.
        .onReceive(arModel.$measurements) { _ in
            DispatchQueue.main.async {
                arModel.updateSimpsonMaxDeriv()
            }
        }
    }
}
