import SwiftUI
import SwiftData

struct WallEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let space: Space
    var wall: Wall?

    @State private var name = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
            }
            .navigationTitle(wall == nil ? "New Wall" : "Edit Wall")
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
                if let wall {
                    name = wall.name
                } else {
                    name = "W\(space.activeWalls.count + 1)"
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)

        if let wall {
            wall.name = trimmed
            wall.touch()
        } else {
            let new = Wall(name: trimmed, sortIndex: space.activeWalls.count)
            new.space = space
            context.insert(new)
            space.touch()
        }
        dismiss()
    }
}
