//import SwiftUI
//import AVFoundation
//import CoreImage
//
//struct CameraView: UIViewRepresentable {
//    @ObservedObject var arModel: ARModel
//    
//    func makeUIView(context: Context) -> PreviewView {
//        let view = PreviewView()
//        context.coordinator.setupSession(previewView: view)
//        return view
//    }
//
//    func updateUIView(_ uiView: PreviewView, context: Context) {}
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(arModel: arModel)
//    }
//
//    class Coordinator: NSObject, AVCaptureDepthDataOutputDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
//        var arModel: ARModel
//        var captureSession: AVCaptureSession?
//        weak var previewView: PreviewView?
//    
//        init(arModel: ARModel) {
//            self.arModel = arModel
//            super.init()
//        }
//    
//        func setupSession(previewView: PreviewView) {
//            self.previewView = previewView
//    
//            // Create the capture session
//            let session = AVCaptureSession()
//            session.beginConfiguration()
//    
//            // Set the session preset
//            session.sessionPreset = .photo
//    
//            // Find a depth-capable camera device
//            let deviceTypes: [AVCaptureDevice.DeviceType] = [
//                .builtInLiDARDepthCamera,
//                .builtInDualCamera,
//                .builtInDualWideCamera,
//                .builtInTrueDepthCamera
//            ]
//    
//            let discoverySession = AVCaptureDevice.DiscoverySession(
//                deviceTypes: deviceTypes,
//                mediaType: .video,
//                position: .unspecified
//            )
//    
//            guard let depthCamera = discoverySession.devices.first else {
//                print("No depth-capable camera found.")
//                return
//            }
//    
//            do {
//                // Add the video input
//                let videoInput = try AVCaptureDeviceInput(device: depthCamera)
//                if session.canAddInput(videoInput) {
//                    session.addInput(videoInput)
//                } else {
//                    print("Cannot add video input.")
//                    return
//                }
//    
//                // Add the depth data output
//                let depthOutput = AVCaptureDepthDataOutput()
//                depthOutput.isFilteringEnabled = true // Enable smoothing
//                depthOutput.setDelegate(self, callbackQueue: DispatchQueue(label: "depthQueue"))
//                if session.canAddOutput(depthOutput) {
//                    session.addOutput(depthOutput)
//                } else {
//                    print("Cannot add depth data output.")
//                    return
//                }
//    
//                // Connect depth data output
//                if let connection = depthOutput.connection(with: .depthData) {
//                    connection.isEnabled = true
//                } else {
//                    print("Cannot get depth data connection.")
//                    return
//                }
//    
//                // Add video data output
//                let videoDataOutput = AVCaptureVideoDataOutput()
//                videoDataOutput.videoSettings = [
//                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
//                ]
//                videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
//                if session.canAddOutput(videoDataOutput) {
//                    session.addOutput(videoDataOutput)
//                }
//    
//                // Set up the preview layer
//                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
//                previewLayer.videoGravity = .resizeAspectFill
//    
//                DispatchQueue.main.async {
//                    previewView.videoPreviewLayer = previewLayer
//                    previewView.layer.insertSublayer(previewLayer, at: 0)
//                    previewLayer.frame = previewView.bounds
//                }
//    
//                session.commitConfiguration()
//                session.startRunning()
//    
//                self.captureSession = session
//    
//            } catch {
//                print("Error setting up capture session: \(error)")
//            }
//        }
//    
//        // Delegate method for depth data output
//        func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
//            // Process the depth data
//            let depthDataType = kCVPixelFormatType_DepthFloat32 // Use Float32 format
//            let convertedDepthData = depthData.converting(toDepthDataType: depthDataType)
//    
//            let depthDataMap = convertedDepthData.depthDataMap
//            CVPixelBufferLockBaseAddress(depthDataMap, .readOnly)
//    
//            let width = CVPixelBufferGetWidth(depthDataMap)
//            let height = CVPixelBufferGetHeight(depthDataMap)
//            let pixelCount = width * height
//    
//            guard let dataPointer = CVPixelBufferGetBaseAddress(depthDataMap) else {
//                CVPixelBufferUnlockBaseAddress(depthDataMap, .readOnly)
//                return
//            }
//    
//            let floatBuffer = dataPointer.bindMemory(to: Float32.self, capacity: pixelCount)
//    
//            // Debugging: Print raw depth values at central pixel
//            let centerX = width / 2
//            let centerY = height / 2
//            let centerIndex = centerY * width + centerX
//            let rawDepthValue = floatBuffer[centerIndex]
//            print("Raw depth value at center: \(rawDepthValue)")
//    
//            // Keep raw depth value for precise calculations
//            let preciseDepthValue = rawDepthValue
//    
//            // Normalize depth values to create a grayscale image
//            var minDepth = Float.greatestFiniteMagnitude
//            var maxDepth = Float.leastNormalMagnitude
//    
//            for i in 0 ..< pixelCount {
//                let depth = floatBuffer[i]
//                if depth.isFinite {
//                    minDepth = min(minDepth, depth)
//                    maxDepth = max(maxDepth, depth)
//                }
//            }
//    
//            // Avoid division by zero
//            guard maxDepth - minDepth > 0 else {
//                CVPixelBufferUnlockBaseAddress(depthDataMap, .readOnly)
//                return
//            }
//    
//            // Create a buffer for the normalized pixels
//            var depthPixels = [UInt8](repeating: 0, count: pixelCount)
//    
//            for i in 0 ..< pixelCount {
//                let depth = floatBuffer[i]
//                if depth.isFinite {
//                    let normalizedDepth = (depth - minDepth) / (maxDepth - minDepth)
//                    // Invert and scale to 0-255
//                    let pixelValue = UInt8((1.0 - normalizedDepth) * 255.0)
//                    depthPixels[i] = pixelValue
//                } else {
//                    depthPixels[i] = 0
//                }
//            }
//    
//            // Debugging: Print min and max depth values
//            print("Min depth: \(minDepth), Max depth: \(maxDepth)")
//            print("Normalized depth value at center: \(depthPixels[centerIndex])")
//    
//            CVPixelBufferUnlockBaseAddress(depthDataMap, .readOnly)
//    
//            // Extract focal length in pixels
//            if let calibrationData = depthData.cameraCalibrationData {
//                let intrinsicMatrix = calibrationData.intrinsicMatrix
//                let fx = intrinsicMatrix.columns.0.x
//                let fy = intrinsicMatrix.columns.1.y
//                let focalLengthPixels = (Double(fx) + Double(fy)) / 2.0
//                DispatchQueue.main.async {
//                    self.arModel.focalLengthPixels = focalLengthPixels
//                }
//            }
//    
//            // Create a Data object from the depthPixels buffer
//            let depthData = Data(depthPixels)
//    
//            // Create a CGDataProvider with the Data object
//            guard let depthDataProvider = CGDataProvider(data: depthData as CFData) else { return }
//    
//            // Create CGImage from depth data
//            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
//            guard let depthCGImage = CGImage(
//                width: width,
//                height: height,
//                bitsPerComponent: 8,
//                bitsPerPixel: 8,
//                bytesPerRow: width,
//                space: CGColorSpaceCreateDeviceGray(),
//                bitmapInfo: bitmapInfo,
//                provider: depthDataProvider,
//                decode: nil,
//                shouldInterpolate: false,
//                intent: .defaultIntent
//            ) else { return }
//    
//            var ciImage = CIImage(cgImage: depthCGImage)
//    
//            // Correct the orientation to match the preview layer
//            let ciOrientation: CGImagePropertyOrientation = .right
//            let correctedImage = ciImage.oriented(ciOrientation)
//    
//            // Convert the CIImage to UIImage
//            let context = CIContext()
//            if let cgImage = context.createCGImage(correctedImage, from: correctedImage.extent) {
//                let depthImage = UIImage(cgImage: cgImage)
//    
//                // Update arModel
//                DispatchQueue.main.async {
//                    self.arModel.depthMapImage = depthImage
//                    self.arModel.centralDepth = preciseDepthValue.isFinite ? Double(preciseDepthValue) : nil
//                }
//            }
//        }
//    
//        // Delegate method for video data output
//        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//            // Process video frames
//            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
//                processVideoFrame(pixelBuffer)
//            }
//        }
//    
//        func processVideoFrame(_ pixelBuffer: CVPixelBuffer) {
//            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
//            defer {
//                CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
//            }
//            
//            let width = CVPixelBufferGetWidth(pixelBuffer)
//            let height = CVPixelBufferGetHeight(pixelBuffer)
//            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
//            guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
//            let buffer = baseAddress.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
//            
//            let columnX = width / 2
//            var grayscaleColumn = [UInt8](repeating: 0, count: height)
//            
//            for y in 0..<height {
//                let offset = y * bytesPerRow + columnX * 4
//                // Assuming BGRA format
//                let b = buffer[offset]
//                let g = buffer[offset + 1]
//                let r = buffer[offset + 2]
//                let gray = UInt8(0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
//                grayscaleColumn[y] = gray
//            }
//            
//            DispatchQueue.main.async {
//                self.arModel.updateGrayscaleColumn(grayscaleColumn)
//            }
//        }
//    }
//}
//
//// A UIView to hold the preview layer
//class PreviewView: UIView {
//    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
//    
//    override func layoutSubviews() {
//        super.layoutSubviews()
//        videoPreviewLayer?.frame = bounds
//    }
//}
