import SwiftUI
import SwiftData

struct ProjectEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil when creating a new project.
    var project: Project?

    @State private var name = ""
    @State private var bridgeIdentifier = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Bridge ID (optional)", text: $bridgeIdentifier)
            }
            .navigationTitle(project == nil ? "New Project" : "Edit Project")
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
                if let project {
                    name = project.name
                    bridgeIdentifier = project.bridgeIdentifier ?? ""
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedID = bridgeIdentifier.trimmingCharacters(in: .whitespaces)

        if let project {
            project.name = trimmedName
            project.bridgeIdentifier = trimmedID.isEmpty ? nil : trimmedID
            project.touch()
        } else {
            let new = Project(
                name: trimmedName,
                bridgeIdentifier: trimmedID.isEmpty ? nil : trimmedID
            )
            context.insert(new)
        }
        dismiss()
    }
}
