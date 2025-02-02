import SwiftUI

struct GraphView: View {
    var originalData: [Double]
    var smoothedData: [Double]
    var edgePositions: [Int] = []
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let dataCount = originalData.count
            guard dataCount > 1 else { return AnyView(EmptyView()) }
            
            let step = width / CGFloat(dataCount - 1)
            let maxValue = max(originalData.max() ?? 1.0, smoothedData.max() ?? 1.0)
            let orangeLineOffset: CGFloat = 20 // Adjust this value to shift the orange line up
            
            return AnyView(
                ZStack {
                    // Original Grayscale Data (Blue Line)
                    Path { path in
                        for i in 0..<dataCount {
                            let x = CGFloat(i) * step
                            let y = height - (CGFloat(originalData[i]) / CGFloat(maxValue)) * height
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                    
                    // Smoothed Grayscale Data (Orange Line)
                    Path { path in
                        for i in 0..<dataCount {
                            let x = CGFloat(i) * step
                            let y = height - (CGFloat(smoothedData[i]) / CGFloat(maxValue)) * height + orangeLineOffset
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.orange, lineWidth: 2)
                    
                    // Edge Positions (Red Lines)
                    ForEach(edgePositions, id: \.self) { pos in
                        let x = CGFloat(pos) * step
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: height))
                        }
                        .stroke(Color.red, lineWidth: 1)
                    }
                }
            )
        }
    }
}
