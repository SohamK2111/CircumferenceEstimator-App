import SwiftUI
import AVFoundation
import CoreImage

struct CameraView: UIViewRepresentable {
    @ObservedObject var arModel: ARModel
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        context.coordinator.setupSession(previewView: view)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(arModel: arModel)
    }

    class Coordinator: NSObject, AVCaptureDepthDataOutputDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
        var arModel: ARModel
        var captureSession: AVCaptureSession?
        weak var previewView: PreviewView?
    
        init(arModel: ARModel) {
            self.arModel = arModel
            super.init()
        }
    
        func setupSession(previewView: PreviewView) {
            self.previewView = previewView
    
            // Create the capture session
            let session = AVCaptureSession()
            session.beginConfiguration()
    
            // Set the session preset (photo or high)
            session.sessionPreset = .photo
    
            // **LiDAR Only**: We only discover LiDAR camera devices here
            let deviceTypes: [AVCaptureDevice.DeviceType] = [
                .builtInLiDARDepthCamera
            ]
            
            // On an iPhone/iPad that doesn't have LiDAR,
            // this discovery will return an empty 'devices' list.
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: .unspecified
            )
    
            // If we can't find a LiDAR camera, we bail out.
            guard let lidarCamera = discoverySession.devices.first else {
                print("No LiDAR camera found.")
                session.commitConfiguration()
                return
            }
    
            do {
                // Add the video input from the LiDAR camera
                let videoInput = try AVCaptureDeviceInput(device: lidarCamera)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                } else {
                    print("Cannot add video input from LiDAR.")
                    session.commitConfiguration()
                    return
                }
    
                // Add the depth data output
                let depthOutput = AVCaptureDepthDataOutput()
                depthOutput.isFilteringEnabled = true // Depth smoothing
                depthOutput.setDelegate(self, callbackQueue: DispatchQueue(label: "depthQueue"))
                if session.canAddOutput(depthOutput) {
                    session.addOutput(depthOutput)
                } else {
                    print("Cannot add LiDAR depth data output.")
                    session.commitConfiguration()
                    return
                }
    
                // Connect the depth data output to .depthData
                if let connection = depthOutput.connection(with: .depthData) {
                    connection.isEnabled = true
                } else {
                    print("Cannot get LiDAR depth data connection.")
                    session.commitConfiguration()
                    return
                }
    
                // Add video data output (for the live preview)
                let videoDataOutput = AVCaptureVideoDataOutput()
                videoDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
                if session.canAddOutput(videoDataOutput) {
                    session.addOutput(videoDataOutput)
                }
    
                // Set up the preview layer
                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer.videoGravity = .resizeAspectFill
    
                // Install the preview layer in our SwiftUI view
                DispatchQueue.main.async {
                    previewView.videoPreviewLayer = previewLayer
                    previewView.layer.insertSublayer(previewLayer, at: 0)
                    previewLayer.frame = previewView.bounds
                }
    
                session.commitConfiguration()
                session.startRunning()
    
                self.captureSession = session
    
            } catch {
                print("Error setting up LiDAR capture session: \(error)")
            }
        }
    
        // MARK: - AVCaptureDepthDataOutputDelegate
        func depthDataOutput(_ output: AVCaptureDepthDataOutput,
                             didOutput depthData: AVDepthData,
                             timestamp: CMTime,
                             connection: AVCaptureConnection) {
            
            // Convert to 32-bit float format (nominally in meters for LiDAR)
            let depthDataType = kCVPixelFormatType_DepthFloat32
            let convertedDepthData = depthData.converting(toDepthDataType: depthDataType)
    
            let depthDataMap = convertedDepthData.depthDataMap
            CVPixelBufferLockBaseAddress(depthDataMap, .readOnly)
    
            let width = CVPixelBufferGetWidth(depthDataMap)
            let height = CVPixelBufferGetHeight(depthDataMap)
            let pixelCount = width * height
    
            guard let dataPointer = CVPixelBufferGetBaseAddress(depthDataMap) else {
                CVPixelBufferUnlockBaseAddress(depthDataMap, .readOnly)
                return
            }
    
            let floatBuffer = dataPointer.bindMemory(to: Float32.self, capacity: pixelCount)
    
            // Center pixel index
            let centerX = width / 2
            let centerY = height / 2
            let centerIndex = centerY * width + centerX
            let rawDepthValue = floatBuffer[centerIndex]
            print("LiDAR raw depth at center: \(rawDepthValue) meters")
    
            // Keep raw depth value for further usage in arModel
            let preciseDepthValue = rawDepthValue
    
            // 1) Find min & max depth to normalize 0..255
            var minDepth = Float.greatestFiniteMagnitude
            var maxDepth = Float.leastNormalMagnitude
            for i in 0 ..< pixelCount {
                let depth = floatBuffer[i]
                if depth.isFinite {
                    minDepth = min(minDepth, depth)
                    maxDepth = max(maxDepth, depth)
                }
            }
    
            guard maxDepth > minDepth else {
                CVPixelBufferUnlockBaseAddress(depthDataMap, .readOnly)
                return
            }
    
            // 2) Build a grayscale array for the entire depth map
            var depthPixels = [UInt8](repeating: 0, count: pixelCount)
            for i in 0 ..< pixelCount {
                let depth = floatBuffer[i]
                if depth.isFinite {
                    let normalizedDepth = (depth - minDepth) / (maxDepth - minDepth)
                    // Invert so nearer = lighter, or keep as-is if you prefer
                    let pixelValue = UInt8((1.0 - normalizedDepth) * 255.0)
                    depthPixels[i] = pixelValue
                } else {
                    depthPixels[i] = 0
                }
            }
    
            CVPixelBufferUnlockBaseAddress(depthDataMap, .readOnly)
    
            // If calibration data is present, we can get focal length in pixels
            if let calibrationData = depthData.cameraCalibrationData {
                let intrinsicMatrix = calibrationData.intrinsicMatrix
                let fx = intrinsicMatrix.columns.0.x
                let fy = intrinsicMatrix.columns.1.y
                let focalLengthPixels = (Double(fx) + Double(fy)) / 2.0
                DispatchQueue.main.async {
                    self.arModel.focalLengthPixels = focalLengthPixels
                }
            }
    
            // 3) Convert that depthPixels array into a CGImage -> UIImage
            let depthData = Data(depthPixels)
            guard let depthDataProvider = CGDataProvider(data: depthData as CFData) else { return }
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            guard let depthCGImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: bitmapInfo,
                provider: depthDataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            ) else { return }
    
            // Convert the CGImage to CIImage for orientation fix
            var ciImage = CIImage(cgImage: depthCGImage)
            let ciOrientation: CGImagePropertyOrientation = .right
            let correctedImage = ciImage.oriented(ciOrientation)
    
            // Finally build a UIImage
            let context = CIContext()
            if let cgImage = context.createCGImage(correctedImage, from: correctedImage.extent) {
                let depthImage = UIImage(cgImage: cgImage)
    
                // Update your ARModel on the main thread
                DispatchQueue.main.async {
                    self.arModel.depthMapImage = depthImage
                    self.arModel.centralDepth = preciseDepthValue.isFinite ? Double(preciseDepthValue) : nil
                }
            }
        }
    
        // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
            // We process the main video frames here
            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                processVideoFrame(pixelBuffer)
            }
        }
    
        func processVideoFrame(_ pixelBuffer: CVPixelBuffer) {
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            }
            
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
            let buffer = baseAddress.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
            
            let columnX = width / 2
            var grayscaleColumn = [UInt8](repeating: 0, count: height)
            
            // Convert a vertical column from BGRA to grayscale
            for y in 0..<height {
                let offset = y * bytesPerRow + columnX * 4
                // BGRA format
                let b = buffer[offset]
                let g = buffer[offset + 1]
                let r = buffer[offset + 2]
                let gray = UInt8(0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
                grayscaleColumn[y] = gray
            }
            
            DispatchQueue.main.async {
                self.arModel.updateGrayscaleColumn(grayscaleColumn)
            }
        }
    }
}

// A UIView to hold the preview layer
class PreviewView: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer?.frame = bounds
    }
}

