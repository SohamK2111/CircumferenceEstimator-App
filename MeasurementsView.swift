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
            
            // "Clear All" button appears only when there are measurements.
            if !arModel.measurements.isEmpty {
                Button(action: {
                    arModel.measurements.removeAll()
                }) {
                    Text("Clear All")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.red)
                }
                // Optional: set a different background for this row.
                .listRowBackground(Color(UIColor.systemGroupedBackground))
            }
        }
        .navigationTitle("Saved Measurements")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()  // Enables swipe-to-delete.
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
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
