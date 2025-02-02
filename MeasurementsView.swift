////import SwiftUI
//////MARK: - This class displays the key measurements required to estimate the width of an object.
////struct MeasurementsView: View {
////    @ObservedObject var arModel: ARModel
////    
////    var body: some View {
////        List(arModel.measurements) { measurement in
////            VStack(alignment: .leading, spacing: 5) {
////                Text("Timestamp: \(measurement.timestamp, formatter: DateFormatter.measurementDateFormatter)")
////                Text("Edge Distance: \(measurement.edgeDistance) pixels")
////                Text(String(format: "Central Depth: %.2f meters", measurement.centralDepth))
////                Text(String(format: "Real Width: %.2f meters", measurement.realWidth))
////            }
////            .padding()
////        }
////        .navigationBarTitle("Saved Measurements", displayMode: .inline)
////
////
////    }
////}
////
////extension DateFormatter {
////    static let measurementDateFormatter: DateFormatter = {
////        let formatter = DateFormatter()
////        formatter.dateStyle = .medium
////        formatter.timeStyle = .medium
////        return formatter
////    }()
////}
//
//import SwiftUI
//
//struct MeasurementsView: View {
//    @ObservedObject var arModel: ARModel
//    
//    var body: some View {
//        List {
//            ForEach(arModel.measurements) { measurement in
//                VStack(alignment: .leading, spacing: 5) {
//                    Text("Timestamp: \(measurement.timestamp, formatter: DateFormatter.measurementDateFormatter)")
//                    Text("Edge Distance: \(measurement.edgeDistance) px")
//                    Text(String(format: "Central Depth: %.2f m", measurement.centralDepth))
//                    Text(String(format: "Real Width: %.2f cm", measurement.realWidth * 100))
//                    Text(String(format: "Rotation Angle: %.1f°", measurement.rotationAngle))
//                }
//                .padding(.vertical, 8)
//            }
//        }
//        .navigationTitle("Saved Measurements")
//        .toolbar {
//            // Button to navigate to calculation page
//            NavigationLink(destination: CalculationView(arModel: arModel)) {
//                Text("Calculate")
//            }
//        }
//    }
//}
//
//extension DateFormatter {
//    static let measurementDateFormatter: DateFormatter = {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .medium
//        return formatter
//    }()
//}
//
//import SwiftUI
//
//// A row view to display and edit each measurement's rotation angle.
//struct MeasurementRowView: View {
//    @Binding var measurement: ARModel.Measurement
//
//    static let angleFormatter: NumberFormatter = {
//        let formatter = NumberFormatter()
//        formatter.numberStyle = .decimal
//        formatter.maximumFractionDigits = 1
//        return formatter
//    }()
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 5) {
//            Text("Timestamp: \(measurement.timestamp, formatter: DateFormatter.measurementDateFormatter)")
//            Text("Edge Distance: \(measurement.edgeDistance) px")
//            Text(String(format: "Central Depth: %.2f m", measurement.centralDepth))
//            Text(String(format: "Real Width: %.2f cm", measurement.realWidth * 100))
//            HStack {
//                Text("Rotation Angle:")
//                // Editable text field with a Done (enter) button on the keyboard.
//                TextField("Angle", value: $measurement.rotationAngle, formatter: MeasurementRowView.angleFormatter)
//                    .keyboardType(.decimalPad)
//                    .submitLabel(.done)
//                    .onSubmit {
//                        // Dismiss the keyboard.
//                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//                    }
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//            }
//        }
//        .padding(.vertical, 8)
//    }
//}
//
//struct MeasurementsView: View {
//    @ObservedObject var arModel: ARModel
//    
//    var body: some View {
//        List {
//            ForEach($arModel.measurements) { $measurement in
//                MeasurementRowView(measurement: $measurement)
//            }
//            .onDelete(perform: deleteMeasurement)
//        }
////        .navigationTitle("Saved Measurements")
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                EditButton()  // Enables swipe-to-delete.
//            }
//            ToolbarItemGroup(placement: .navigationBarTrailing) {
//                // Button to auto-assign equispaced angles.
//                Button(action: autoAssignAngles) {
//                    Text("Auto Angles")
//                }
//                // Existing Calculate navigation link.
//                NavigationLink(destination: CalculationView(arModel: arModel)) {
//                    Text("Calculate")
//                }
//            }
//        }
//    }
//    
//    private func deleteMeasurement(at offsets: IndexSet) {
//        arModel.measurements.remove(atOffsets: offsets)
//    }
//    
//    /// Automatically sets each measurement's rotation angle to be equispaced from 0 to 360.
//    private func autoAssignAngles() {
//        let count = arModel.measurements.count
//        if count > 1 {
//            for i in 0..<count {
//                let newAngle = 360.0 * Double(i) / Double(count - 1)
//                arModel.measurements[i].rotationAngle = Float(newAngle)
//            }
//        } else if count == 1 {
//            arModel.measurements[0].rotationAngle = 0
//        }
//    }
//}
//
//extension DateFormatter {
//    static let measurementDateFormatter: DateFormatter = {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .medium
//        return formatter
//    }()
//}
//

import SwiftUI

struct MeasurementRowView: View {
    @Binding var measurement: ARModel.Measurement

    static let angleFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Timestamp: \(measurement.timestamp, formatter: DateFormatter.measurementDateFormatter)")
            Text("Edge Distance: \(measurement.edgeDistance) px")
            Text(String(format: "Central Depth: %.2f m", measurement.centralDepth))
            Text(String(format: "Real Width: %.2f cm", measurement.realWidth * 100))
            HStack {
                Text("Rotation Angle:")
                TextField("Angle",
                          value: $measurement.rotationAngle,
                          formatter: MeasurementRowView.angleFormatter)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                // Dismiss the keyboard by resigning first responder.
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                                to: nil, from: nil, for: nil)
                            }
                        }
                    }
            }
        }
        .padding(.vertical, 8)
    }
}


struct MeasurementsView: View {
    @ObservedObject var arModel: ARModel
    
    var body: some View {
        List {
            ForEach($arModel.measurements) { $measurement in
                MeasurementRowView(measurement: $measurement)
            }
            .onDelete(perform: deleteMeasurement)
        }
        .navigationTitle("Saved Measurements")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()  // Enables swipe-to-delete.
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Auto-assign equispaced angles button.
                Button(action: autoAssignAngles) {
                    Text("Auto Angles")
                }
                NavigationLink(destination: CalculationView(arModel: arModel)) {
                    Text("Calculate")
                }
            }
        }
    }
    
    private func deleteMeasurement(at offsets: IndexSet) {
        arModel.measurements.remove(atOffsets: offsets)
    }
    
    /// Automatically sets each measurement’s rotation angle equispaced from 0 to 360.
    private func autoAssignAngles() {
        let count = arModel.measurements.count
        if count > 1 {
            for i in 0..<count {
                let newAngle = 360.0 * Double(i) / Double(count - 1)
                arModel.measurements[i].rotationAngle = Float(newAngle)
            }
        } else if count == 1 {
            arModel.measurements[0].rotationAngle = 0
        }
    }
}

extension DateFormatter {
    static let measurementDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
