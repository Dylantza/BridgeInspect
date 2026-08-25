import SwiftUI
import SwiftData

struct SpaceEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let project: Project
    var space: Space?

    @State private var name = ""
    /// Only used when creating. Walls are added freely afterwards.
    @State private var initialWallCount = 4

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)

                if space == nil {
                    Stepper("Start with \(initialWallCount) walls",
                            value: $initialWallCount, in: 0...20)
                    Text("You can add or remove walls at any time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(space == nil ? "New Space" : "Edit Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!isValid)
                }
            }
            .onAppear {
                if let space {
                    name = space.name
                } else {
                    name = suggestedName()
                }
            }
        }
    }

    /// "Space 01", "Space 02", … based on how many already exist.
    private func suggestedName() -> String {
        let next = project.activeSpaces.count + 1
        return String(format: "Space %02d", next)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)

        if let space {
            space.name = trimmed
            space.touch()
        } else {
            let new = Space(name: trimmed, sortIndex: project.activeSpaces.count)
            new.project = project
            context.insert(new)

            for index in 0..<initialWallCount {
                let wall = Wall(name: "W\(index + 1)", sortIndex: index)
                wall.space = new
                context.insert(wall)
            }
            project.touch()
        }
        dismiss()
    }
}
