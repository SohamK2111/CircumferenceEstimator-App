import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var arModel: ARModel

    func makeCoordinator() -> Coordinator {
        Coordinator(arModel: arModel)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Set the session delegate
        arView.session.delegate = context.coordinator

        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = []
        arView.session.run(configuration)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Update UI if needed
    }

    class Coordinator: NSObject, ARSessionDelegate {
        var arModel: ARModel

        init(arModel: ARModel) {
            self.arModel = arModel
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Process the camera frame
            arModel.processFrame(frame)
        }
    }
}
