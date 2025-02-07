import SwiftUI

// Enum to indicate which calculation method to use.
enum CalculationMode {
    case full
    case twoPoint
    case circular
}

struct CalculationView: View {
    @ObservedObject var arModel: ARModel
    let mode: CalculationMode
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Select the appropriate computation.
            let circumference: Double = {
                switch mode {
                case .full:
                    return computeCircumferenceFull()
                case .twoPoint:
                    return computeCircumferenceTwoPoint()
                case .circular:
                    return computeCircumferenceCircular()
                }
            }()
            
            Text("Approx. Result:")
                .font(.headline)
            
            Text(String(format: "%.2f cm", circumference * 100))
                .font(.largeTitle)
                .bold()
                .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Circumference Calc")
    }
    
    // MARK: - Full integration (original method)
    private func computeCircumferenceFull() -> Double {
        let ms = arModel.measurements
        // Ensure at least 3 measurements for integration.
        if ms.count < 3 { return 0 }
        
        var widths: [Double] = []
        var angles: [Double] = []
        for m in ms {
            widths.append(m.realWidth)
            angles.append(Double(m.rotationAngle))
        }
        
        return integratedCircumference(widths: widths, anglesDegrees: angles)
    }
    
    // MARK: - 2-Point Estimate
    // Requires exactly 2 measurements. From measurements [x, y],
    // we build new arrays: widths = [x, y, x, y, x] and angles = [0, 90, 180, 270, 360].
    private func computeCircumferenceTwoPoint() -> Double {
        let ms = arModel.measurements
        if ms.count != 2 { return 0 }
        let x = ms[0].realWidth
        let y = ms[1].realWidth
        let widths = [x, y, x, y, x]
        let angles = [0.0, 90.0, 180.0, 270.0, 360.0]
        return integratedCircumference(widths: widths, anglesDegrees: angles)
    }
    
    // MARK: - Circular Approximation
    // Requires exactly 1 measurement. Simply returns π * diameter.
    private func computeCircumferenceCircular() -> Double {
        let ms = arModel.measurements
        if ms.count != 1 { return 0 }
        return .pi * ms[0].realWidth
    }
    
    // MARK: - Helper: Integrated Circumference
    // Given arrays of widths (in meters) and corresponding angles (in degrees),
    // compute the integral using Simpson’s rule over the integrand: width + d²(width)/dθ².
    private func integratedCircumference(widths: [Double], anglesDegrees: [Double]) -> Double {
        // Sort the pairs by angle.
        let combined = zip(anglesDegrees, widths).sorted { $0.0 < $1.0 }
        let sortedAngles = combined.map { $0.0 }
        let sortedWidths = combined.map { $0.1 }
        // Convert angles from degrees to radians.
        let thetaRads = sortedAngles.map { $0 * .pi / 180.0 }
        guard thetaRads.count >= 3 else { return 0 }
        let deltaTheta = thetaRads[1] - thetaRads[0]
        if deltaTheta <= 0 { return 0 }
        
        let dw_dtheta = gradient(sortedWidths, dx: deltaTheta)
        let d2w_dtheta2 = gradient(dw_dtheta, dx: deltaTheta)
        var integrand: [Double] = []
        for i in 0..<sortedWidths.count {
            integrand.append(sortedWidths[i] + d2w_dtheta2[i])
        }
        return simpson(integrand, dx: deltaTheta)
    }
    
    // MARK: - Numerical Gradient
    private func gradient(_ y: [Double], dx: Double) -> [Double] {
        let n = y.count
        guard n >= 2, dx > 0 else { return Array(repeating: 0, count: n) }
        
        var g = [Double](repeating: 0, count: n)
        
        // Forward difference for the first point.
        g[0] = (y[1] - y[0]) / dx
        
        // Central difference for interior points.
        for i in 1..<(n - 1) {
            g[i] = (y[i + 1] - y[i - 1]) / (2 * dx)
        }
        
        // Backward difference for the last point.
        g[n - 1] = (y[n - 1] - y[n - 2]) / dx
        
        return g
    }
    
    // MARK: - Simpson's Rule Integration
    private func simpson(_ y: [Double], dx: Double) -> Double {
        let n = y.count
        if n < 2 { return 0 }
        
        let intervals = n - 1
        var sum = 0.0
        if intervals % 2 == 0 {
            // Even number of intervals.
            var i = 0
            while i < intervals {
                let y0 = y[i]
                let y1 = y[i + 1]
                let y2 = y[i + 2]
                sum += (dx / 6.0) * (y0 + 4.0 * y1 + y2)
                i += 2
            }
        } else {
            // Odd number of intervals: Simpson for most, then trapezoidal rule for the last interval.
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
}
