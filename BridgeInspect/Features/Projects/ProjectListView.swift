import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Project> { !$0.isDeleted },
           sort: \Project.createdAt, order: .reverse)
    private var projects: [Project]

    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(projects) { project in
                    NavigationLink(value: project) {
                        HStack(spacing: 12) {
                            Image(systemName: "building.columns.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.Palette.accent)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name)
                                    .font(.body.weight(.medium))
                                HStack(spacing: 4) {
                                    Text("\(project.activeSpaces.count) spaces")
                                    if let id = project.bridgeIdentifier, !id.isEmpty {
                                        Text("·")
                                        Text(id)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Projects")
            .navigationDestination(for: Project.self) { project in
                SpaceListView(project: project)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Project", systemImage: "plus") { showingAdd = true }
                }
            }
            .overlay {
                if projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder",
                        description: Text("Add a bridge to get started.")
                    )
                }
            }
            .sheet(isPresented: $showingAdd) {
                ProjectEditSheet()
            }
        }
    }

    /// Soft delete: a hard delete is invisible to a device that has been
    /// offline, which would resurrect the row on its next upload.
    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let project = projects[index]
            project.isDeleted = true
            project.touch()
        }
    }
}
