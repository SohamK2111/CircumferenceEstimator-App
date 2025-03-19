import SwiftUI

struct DepthMapView: View {
    /// A 1D vertical slice of LiDAR data in meters.
    /// Indices in [0..(depthData.count-1)] correspond to row y-values in the depth map.
    var depthData: [Float]
    
    /// Indices where gradient > threshold
    var depthEdges: [Int]
    
    /// Subset of `depthEdges` we want to highlight
    var usedDepthEdges: [Int]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            if depthData.isEmpty {
                Color.clear
            } else {
                // Hard-coded chart range from 0..1.5 meters; tweak as needed.
                let minDepth: Float = 0.0
                let maxDepth: Float = 2
                let range = maxDepth - minDepth
                
                let axisWidth: CGFloat = 50
                let spacing: CGFloat = 8
                let plotWidth = width - axisWidth - spacing
                let plotHeight = height
                
                // Convert slice indices => X
                let scaleX = plotWidth / CGFloat(depthData.count - 1)
                // Convert meters => Y
                let scaleY = (range > 0) ? (plotHeight / CGFloat(range)) : 1.0
                
                HStack(spacing: spacing) {
                    // Y-axis labels
                    VStack {
                        ForEach((0...5).reversed(), id: \.self) { i in
                            let fraction = CGFloat(i) / 5.0
                            let labelDepth = minDepth + Float(fraction) * range
                            Text(String(format: "%.2f m", labelDepth))
                                .font(.caption2)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .frame(width: axisWidth)
                    
                    ZStack(alignment: .topLeading) {
                        // Plot the LiDAR slice as a blue line.
                        Path { path in
                            for (i, val) in depthData.enumerated() {
                                let clamped = max(minDepth, min(val, maxDepth))
                                // Flip X direction:
                                let x = plotWidth - CGFloat(i) * scaleX
                                let y = plotHeight - (CGFloat(clamped - minDepth) * scaleY)
                                
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.blue, lineWidth: 2)
                        
                        // Draw red vertical lines for detected edges.
                        if !depthEdges.isEmpty {
                            Path { edgePath in
                                for edgeIndex in depthEdges {
                                    guard edgeIndex >= 0, edgeIndex < depthData.count else { continue }
                                    let x = plotWidth - CGFloat(edgeIndex) * scaleX
                                    edgePath.move(to: CGPoint(x: x, y: 0))
                                    edgePath.addLine(to: CGPoint(x: x, y: plotHeight))
                                }
                            }
                            .stroke(Color.red, lineWidth: 1.5)
                        }
                    }
                    .frame(width: plotWidth, height: plotHeight)
                }
            }
        }
        .padding()
    }
}
