import SwiftUI
import SwiftData

struct InspectionDetailSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let wall: Wall
    let type: InspectionType

    @State private var status: InspectionStatus = .notStarted
    @State private var resultText = ""
    @State private var notes = ""
    @State private var frameCount = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    // Three large targets rather than a picker list: setting
                    // status is the whole point of this sheet and should cost
                    // one tap with a gloved hand.
                    HStack(spacing: 8) {
                        ForEach(InspectionStatus.allCases) { option in
                            statusButton(option)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                if type.tracksFrameCount {
                    Section("Frames Shot") {
                        TextField("Number of frames", text: $frameCount)
                            .keyboardType(.numberPad)
                    }
                }

                Section("Result") {
                    TextField("Result", text: $resultText, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("\(wall.name) · \(type.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func statusButton(_ option: InspectionStatus) -> some View {
        let selected = status == option
        return Button {
            withAnimation(.easeOut(duration: 0.12)) { status = option }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: 6) {
                StatusGlyph(status: option, size: 17)
                Text(option.shortTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(selected ? AnyShapeStyle(option.tint) : AnyShapeStyle(.secondary))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background {
                RoundedRectangle(cornerRadius: Theme.Metrics.corner)
                    .fill(selected ? option.tint.opacity(0.14) : Color.primary.opacity(0.035))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Metrics.corner)
                            .strokeBorder(
                                selected ? option.tint.opacity(0.85) : .clear,
                                lineWidth: 1.8
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func load() {
        guard let inspection = wall.inspection(for: type) else { return }
        status = inspection.status
        resultText = inspection.resultText ?? ""
        notes = inspection.notes ?? ""
        frameCount = inspection.frameCount.map(String.init) ?? ""
    }

    private func save() {
        let inspection = InspectionResolver.resolve(
            wall: wall, type: type, context: context
        )
        inspection.status = status
        inspection.resultText = resultText.isEmpty ? nil : resultText
        inspection.notes = notes.isEmpty ? nil : notes
        inspection.frameCount = type.tracksFrameCount ? Int(frameCount) : nil
        inspection.touch()
        dismiss()
    }
}
