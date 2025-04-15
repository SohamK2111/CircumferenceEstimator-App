import SwiftUI

struct SettingsView: View {
    @ObservedObject var arModel: ARModel
    
    var body: some View {
        Form {
            Section(header: Text("Test Mode")) {
                Toggle("Enable Test Mode", isOn: $arModel.isTestMode)
            }
            
            Section(header: Text("Edge Detection Threshold")) {
                Slider(value: $arModel.depthEdgeThreshold, in: 0.01...1, step: 0.01)
                Text(String(format: "Threshold: %.2f", arModel.depthEdgeThreshold))
            }
            
            Section(header: Text("Scaling Constant")) {
                Slider(value: $arModel.constant, in: 0.0...10.0, step: 1.0)
                Text("Scaling Constant: \(Int(arModel.constant))")
            }
            
            Section(header: Text("Divider in Correction Step")) {
                Slider(value: $arModel.divider, in: 2.0...3.0, step: 0.05)
                Text(String(format: "Divider: %.2f", arModel.divider))
            }
            
            Section(header: Text("Correction for Clothing")) {
                Slider(value: $arModel.clothingWidth, in: -5...5, step: 0.1)
                Text(String(format: "Clothing Correction: %.2f", arModel.clothingWidth))
                }
            
            Section(header: Text("LiDAR Row data to average")) {
                Slider(value: Binding(
                    get: { Double(arModel.lidarRows) },
                    set: { arModel.lidarRows = Int($0) }
                ), in: 1...7, step: 1)
                
                Text("LiDAR Rows: \(arModel.lidarRows)")
            }
            
            Section(header: Text("Continuous Save Interval")) {
                Slider(value: $arModel.saveInterval, in: 0.1...5, step: 0.1)
                Text(String(format: "Save Interval: %.1f s", arModel.saveInterval))
            }
            
            Section(header: Text("Display Options")) {
                Toggle("Show Depth Map", isOn: $arModel.showDepthMapView)
                Toggle("Show Edge Overlay", isOn: $arModel.showEdgeOverlay)
            }
        }
        .navigationTitle("Settings")
    }
}

