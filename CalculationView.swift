import SwiftUI

struct CalculationView: View {
    @ObservedObject var arModel: ARModel
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            let circumference = computeCircumference()
            
            Text("Approx. Integral Result:")
                .font(.headline)
            
            Text(String(format: "%.2f cm", circumference * 100))
                .font(.largeTitle)
                .bold()
                .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Circumference Calc")
    }
    
    // Gathers (w, theta) from `arModel.measurements`, sorts by ascending theta (in degrees),
    // then **converts** degrees -> radians, and does:
    //   integrand(θ) = w(θ) + d²w/dθ²
    //   circumference = Simpson(integrand)
    private func computeCircumference() -> Double {
        let ms = arModel.measurements
        if ms.count < 3 { return 0 }
        
        // 1) Build arrays: w_values (m), theta_degs (degrees)
        var w_values: [Double] = []
        var theta_degs: [Double] = []
        
        for m in ms {
            w_values.append(m.realWidth)
            theta_degs.append(Double(m.rotationAngle)) // in degrees
        }
        
        // 2) Sort by ascending angle
        let combined = zip(theta_degs, w_values).sorted { $0.0 < $1.0 }
        let sortedDegs = combined.map { $0.0 }
        let sortedW    = combined.map { $0.1 }
        
        // 3) Convert degrees -> radians
        let theta_rads = sortedDegs.map { $0 * .pi / 180.0 }
        
        // Must have at least 3 points
        guard theta_rads.count >= 3 else { return 0 }
        
        // 4) Assume uniform spacing => deltaθ = θ[1] - θ[0]
        let deltaTheta = theta_rads[1] - theta_rads[0]
        if deltaTheta <= 0 { return 0 }
        
        // 5) Compute derivatives
        let dw_dtheta   = gradient(sortedW, dx: deltaTheta)
        let d2w_dtheta2 = gradient(dw_dtheta, dx: deltaTheta)
        
        // 6) integrand = w(θ) + d²w/dθ²
        var integrand: [Double] = []
        for i in 0..<sortedW.count {
            integrand.append(sortedW[i] + d2w_dtheta2[i])
        }
        
        // 7) Integrate (Simpson’s rule) in *radians*
        let result = simpson(integrand, dx: deltaTheta)
        return result
    }
    
    // MARK: - gradient
    private func gradient(_ y: [Double], dx: Double) -> [Double] {
        let n = y.count
        guard n >= 2, dx > 0 else { return Array(repeating: 0, count: n) }
        
        var g = [Double](repeating: 0, count: n)
        
        // Forward difference at i=0
        if n > 1 {
            g[0] = (y[1] - y[0]) / dx
        }
        
        // Central difference for interior
        for i in 1..<(n - 1) {
            g[i] = (y[i + 1] - y[i - 1]) / (2 * dx)
        }
        
        // Backward difference at i=n-1
        if n > 1 {
            g[n - 1] = (y[n - 1] - y[n - 2]) / dx
        }
        
        return g
    }
    
    // MARK: - Simpson's rule
    private func simpson(_ y: [Double], dx: Double) -> Double {
        let n = y.count
        if n < 2 { return 0 }
        
        // # intervals = n - 1
        let intervals = n - 1
        
        var sum = 0.0
        // If intervals is even => perfect Simpson across all
        if intervals % 2 == 0 {
            // e.g. 4 intervals => 5 points => n=5, intervals=4
            var i = 0
            while i < intervals {
                let y0 = y[i]
                let y1 = y[i + 1]
                let y2 = y[i + 2]
                sum += (dx / 6.0) * (y0 + 4.0 * y1 + y2)
                i += 2
            }
        } else {
            // If intervals is odd => do Simpson for the first intervals-1, then trapezoid
            var i = 0
            while i < (intervals - 1) {
                let y0 = y[i]
                let y1 = y[i + 1]
                let y2 = y[i + 2]
                sum += (dx / 6.0) * (y0 + 4.0 * y1 + y2)
                i += 2
            }
            // One trapezoid for the last interval
            let yA = y[n - 2]
            let yB = y[n - 1]
            sum += 0.5 * dx * (yA + yB)
        }
        return sum
    }
}
