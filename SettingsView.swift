//
//  SettingsView.swift
//  StereoCircumferenceEstimator
//
//  Created by Soham Karmarkar on 01/02/2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var arModel: ARModel
    
    var body: some View {
        Form {
            Section(header: Text("Edge Detection Threshold")) {
                Slider(value: $arModel.depthEdgeThreshold, in: 0.01...1, step: 0.01)
                Text(String(format: "Threshold: %.2f", arModel.depthEdgeThreshold))
            }
            
//            Section(header: Text("Gaussian Sigma (Absolute)")) {
//                Slider(value: $arModel.gaussianSigma, in: 1...50, step: 1)
//                Text("Sigma: \(Int(arModel.gaussianSigma))")
//            }
        }
        .navigationTitle("Settings")
    }
}
