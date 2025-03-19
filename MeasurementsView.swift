import SwiftUI

// MARK: - MeasurementRowView
struct MeasurementRowView: View {
    @Binding var measurement: ARModel.Measurement
    // Optional interpolated width (if available).
    var interpolatedWidth: Double? = nil

    static let angleFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    // Local state for the text field’s value.
    @State private var widthText: String = ""
    // Use FocusState to monitor when the field is active.
    @FocusState private var isWidthFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Timestamp: \(measurement.timestamp, formatter: DateFormatter.measurementDateFormatter)")
            
            // Editable field for Real Width.
            HStack {
                Text("Real Width:")
                TextField("Real Width", text: $widthText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isWidthFieldFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isWidthFieldFocused = false
                            }
                        }
                    }
                Text("cm")
            }
            // When the view appears, initialize the text field.
            .onAppear {
                updateWidthText()
            }
            // When the focus state changes (i.e. user leaves the field), commit the change.
            .onChange(of: isWidthFieldFocused) { focused in
                if !focused {
                    commitWidthChange()
                }
            }
            // If the measurement changes externally (like via correction) and we're not editing, update the text field.
            .onChange(of: measurement.realWidth) { newValue in
                if !isWidthFieldFocused {
                    updateWidthText()
                }
            }
            
            // Rotation Angle field remains unchanged.
            HStack {
                Text("Rotation Angle:")
                TextField("Angle",
                          value: $measurement.rotationAngle,
                          formatter: Self.angleFormatter)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                                  to: nil, from: nil, for: nil)
                            }
                        }
                    }
            }
        }
        .padding(.vertical, 8)
    }
    
    // Update the text field from the measurement (displaying in centimeters).
    private func updateWidthText() {
        if let width = measurement.realWidth {
            widthText = String(format: "%.2f", width * 100)
        } else {
            widthText = ""
        }
    }
    
    // Commit the text field change to the measurement.
    private func commitWidthChange() {
        if let newValue = Double(widthText) {
            // Convert from centimeters to meters.
            measurement.realWidth = newValue / 100.0
            // Reformat the text field content.
            widthText = String(format: "%.2f", newValue)
        } else {
            measurement.realWidth = nil
            widthText = ""
        }
    }
}
import SwiftUI

// MARK: - MeasurementsView
struct MeasurementsView: View {
    @ObservedObject var arModel: ARModel
    @State private var interpolateMeasurements: Bool = false
    // For programmatic navigation when in test mode.
    @State private var isCalculateActive: Bool = false

    var body: some View {
        List {
            ForEach(arModel.measurements.indices, id: \.self) { index in
                MeasurementRowView(measurement: $arModel.measurements[index],
                                   interpolatedWidth: interpolateMeasurements ? interpolatedWidth(for: index) : nil)
            }
            .onDelete(perform: deleteMeasurement)
            
            if !arModel.measurements.isEmpty {
                Section {
                    Button(action: saveAllMeasurements) {
                        Text("Save")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.blue)
                    }
                }
                
                // Hide these buttons when Test Mode is enabled.
                if !arModel.isTestMode {
                    Section {
                        Button(action: {
                            arModel.applyWidthCorrection()
                            arModel.measurements = arModel.measurements
                        }) {
                            Text("Apply Correction")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Section {
                        Button(action: {
                            arModel.useSymmetry()
                            arModel.measurements = arModel.measurements
                        }) {
                            Text("Use Symmetry")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        arModel.applyClothingCorrection()
                        arModel.measurements = arModel.measurements
                    }) {
                        Text("Correct for Clothing")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.blue)
                    }
                }
                
                Button(action: {
                    arModel.measurements.removeAll()
                }) {
                    Text("Clear All")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.red)
                }
                .listRowBackground(Color(UIColor.systemGroupedBackground))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Calculate") {
                    autoAssignAngles()
                    
                    // Apply correction only if test mode is enabled
                    if arModel.isTestMode {
                        arModel.applyWidthCorrection()
                        arModel.useSymmetry()
                    }
                    
                    arModel.measurements = arModel.measurements
                    isCalculateActive = true
                }
                .background(
                    NavigationLink(destination: CalculationView(arModel: arModel, mode: .full),
                                   isActive: $isCalculateActive) {
                        EmptyView()
                    }
                    .hidden()
                )

                NavigationLink(destination: CalculationView(arModel: arModel, mode: .twoPoint)) {
                    Button(action: {
                        autoAssignAngles()
                        arModel.applyWidthCorrection()
                        arModel.measurements = arModel.measurements
                    }) {
                        Text("2‑Point")
                    }
                }

                NavigationLink(destination: CalculationView(arModel: arModel, mode: .circular)) {
                    Button(action: {
                        autoAssignAngles()
                        arModel.applyWidthCorrection()
                        arModel.measurements = arModel.measurements
                    }) {
                        Text("Circle")
                    }
                }
            }
            
            // Only show the Auto Angles button when Test Mode is off.
            if !arModel.isTestMode {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: autoAssignAngles) {
                        Text("Auto Angles")
                    }
                }
            }
        }
    }
    
    private func deleteMeasurement(at offsets: IndexSet) {
        arModel.measurements.remove(atOffsets: offsets)
    }
    
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
    
    /// Returns an interpolated width for a measurement at the given index if it is a placeholder.
    private func interpolatedWidth(for index: Int) -> Double? {
        let measurements = arModel.measurements
        if !measurements[index].isPlaceholder {
            return measurements[index].realWidth
        }
        var prevIndex: Int? = nil
        for i in stride(from: index - 1, through: 0, by: -1) {
            if !measurements[i].isPlaceholder, let _ = measurements[i].realWidth {
                prevIndex = i
                break
            }
        }
        var nextIndex: Int? = nil
        for i in (index + 1)..<measurements.count {
            if !measurements[i].isPlaceholder, let _ = measurements[i].realWidth {
                nextIndex = i
                break
            }
        }
        if let prev = prevIndex, let next = nextIndex,
           let prevWidth = measurements[prev].realWidth,
           let nextWidth = measurements[next].realWidth {
            let factor = Double(index - prev) / Double(next - prev)
            return prevWidth + factor * (nextWidth - prevWidth)
        }
        return nil
    }
    
    // Instead of forcing first responder resignation globally,
    // you can rely on the FocusState in each row (or call this if needed).
    private func saveAllMeasurements() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
