import Foundation
import SwiftUI
import ARKit

class ARModel: ObservableObject {
    @Published var edgeDistance: Int?
    @Published var originalGrayscaleValues: [Double] = []
    @Published var smoothedGrayscaleValues: [Double] = []
    @Published var edgePositions: [Int] = []

    @Published var sigma: Double = 11.0 {
        didSet {
            recomputeEdgeDetection()
        }
    }
    @Published var kernelSize: Int = 21 {
        didSet {
            kernelSize = max(Int(6 * sigma), kernelSize)
            recomputeEdgeDetection()
        }
    }

    private var lastGrayscaleColumn: [UInt8] = []
    private var processingQueue = DispatchQueue(label: "ImageProcessingQueue")

    func processFrame(_ frame: ARFrame) {
        processingQueue.async {
            self.computeEdgeDistance(from: frame.capturedImage)
        }
    }

    private func computeEdgeDistance(from pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return
        }

        let columnX = width / 2
        var grayscaleColumn = [UInt8](repeating: 0, count: height)

        for y in 0..<height {
            let rowBase = baseAddress.advanced(by: y * bytesPerRow)
            let buffer = rowBase.bindMemory(to: UInt8.self, capacity: bytesPerRow)
            grayscaleColumn[y] = buffer[columnX]
        }

        self.lastGrayscaleColumn = grayscaleColumn
        let originalGrayscaleValues = grayscaleColumn.map { Double($0) }
        DispatchQueue.main.async {
            self.originalGrayscaleValues = originalGrayscaleValues
        }

        self.recomputeEdgeDetection()
    }

    private func recomputeEdgeDetection() {
        guard !lastGrayscaleColumn.isEmpty else { return }
        processingQueue.async {
            // Apply Gaussian first derivative (gradient filter)
            let gradientData = self.applyGaussianFirstDerivative(to: self.lastGrayscaleColumn)
            
            // Detect peaks based on magnitude thresholding
            let edges = self.detectEdges(usingMagnitudeThresholdedPeaks: gradientData)

            DispatchQueue.main.async {
                self.smoothedGrayscaleValues = gradientData
                self.edgePositions = edges
                if edges.count >= 2 {
                    let center = edges.count / 2
                    let leftEdge = edges[center - 1]
                    let rightEdge = edges[center]
                    self.edgeDistance = abs(rightEdge - leftEdge)
                } else {
                    self.edgeDistance = nil
                }
            }
        }
    }

    private func detectEdges(usingMagnitudeThresholdedPeaks data: [Double]) -> [Int] {
        var edges: [Int] = []
        let threshold = 0.5 * data.map { abs($0) }.max()! // Threshold based on magnitude

        for i in 1..<data.count - 1 {
            let magnitude = abs(data[i])
            if magnitude > threshold && magnitude > abs(data[i - 1]) && magnitude > abs(data[i + 1]) {
                edges.append(i)
            }
        }

        return edges
    }

    private func applyGaussianFirstDerivative(to data: [UInt8]) -> [Double] {
        let gradientKernel = gaussianFirstDerivativeKernel(size: kernelSize, sigma: sigma)
        let halfKernelSize = kernelSize / 2
        let dataCount = data.count
        var gradientData = [Double](repeating: 0.0, count: dataCount)

        for i in 0..<dataCount {
            var sum: Double = 0.0
            for j in 0..<kernelSize {
                let dataIndex = i + j - halfKernelSize
                let index = min(max(dataIndex, 0), dataCount - 1)
                sum += gradientKernel[j] * Double(data[index])
            }
            gradientData[i] = sum
        }

        return gradientData
    }

    private func gaussianFirstDerivativeKernel(size: Int, sigma: Double) -> [Double] {
        let center = size / 2
        var kernel = [Double](repeating: 0.0, count: size)
        let sigmaCubed = pow(sigma, 3)
        
        for x in 0..<size {
            let distance = Double(x - center)
            let value = -distance * exp(-distance * distance / (2 * sigma * sigma)) / (sqrt(2 * .pi) * sigmaCubed)
            kernel[x] = value
        }

        return kernel
    }
}
