import SwiftUI
import SwiftData

struct SpaceListView: View {
    @Environment(\.modelContext) private var context
    let project: Project

    @State private var showingAdd = false

    private var spaces: [Space] { project.activeSpaces }

    var body: some View {
        List {
            ForEach(spaces) { space in
                NavigationLink(value: space) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(space.name)
                                .font(.body.weight(.medium))
                            Spacer()
                            if space.isComplete {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.Palette.done)
                            } else if space.totalCellCount > 0 {
                                Text("\(space.outstandingCount)")
                                    .font(Theme.Fonts.metric)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        Text("\(space.activeWalls.count) walls")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        CompletionBar(fraction: space.completionFraction)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle(project.name)
        .navigationDestination(for: Space.self) { space in
            SpaceTableView(space: space)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Space", systemImage: "plus") { showingAdd = true }
            }
        }
        .overlay {
            if spaces.isEmpty {
                ContentUnavailableView(
                    "No Spaces",
                    systemImage: "square.grid.2x2",
                    description: Text("Add a space inside this bridge.")
                )
            }
        }
        .sheet(isPresented: $showingAdd) {
            SpaceEditSheet(project: project)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let space = spaces[index]
            space.isDeleted = true
            space.touch()
        }
    }
}
