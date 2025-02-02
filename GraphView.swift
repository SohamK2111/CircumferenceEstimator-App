import SwiftUI

struct GraphView: View {
    var originalData: [Double]
    var smoothedData: [Double]
    var edgePositions: [Int]
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Determine scaling factors
//            let maxValue = max(originalData.max() ?? 1.0, smoothedData.max() ?? 1.0)
//            let minValue = min(originalData.min() ?? 0.0, smoothedData.min() ?? 0.0)
            let maxValue = smoothedData.max() ?? 1.0
            let minValue = smoothedData.min() ?? 0.0
            let scaleX = width / Double(originalData.count)
            let scaleY = height / (maxValue - minValue)
            
            ZStack {
//                // Original Data Line
//                Path { path in
//                    for (index, value) in originalData.enumerated() {
//                        let x = Double(index) * scaleX
//                        let y = height - ((value - minValue) * scaleY)
//                        if index == 0 {
//                            path.move(to: CGPoint(x: x, y: y))
//                        } else {
//                            path.addLine(to: CGPoint(x: x, y: y))
//                        }
//                    }
//                }
//                .stroke(Color.green, lineWidth: 2)
                
                // Smoothed Data Line
                Path { path in
                    for (index, value) in smoothedData.enumerated() {
                        let x = Double(index) * scaleX
                        let y = height - ((value - minValue) * scaleY)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 2)
                
                // Edge Positions
                ForEach(edgePositions, id: \.self) { position in
                    let x = Double(position) * scaleX
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    .stroke(Color.red, lineWidth: 1)
                }
            }
        }
    }
}
