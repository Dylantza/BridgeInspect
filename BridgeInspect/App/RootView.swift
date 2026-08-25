import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Projects", systemImage: "folder") {
                ProjectListView()
            }
            Tab("Sync", systemImage: "arrow.triangle.2.circlepath") {
                SyncPlaceholderView()
            }
        }
        .tint(Theme.Palette.accent)
    }
}

/// Sync lands in Phase 10–13. The tab exists now so the shape of the app is
/// fixed, and so the offline-first promise is stated plainly to the user.
struct SyncPlaceholderView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "internaldrive")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Saved on this device")
                                .font(.body.weight(.medium))
                            Text("All work is stored locally and needs no connection.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Label("Upload", systemImage: "arrow.up.circle")
                        .foregroundStyle(.secondary)
                    Label("Download", systemImage: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Cloud")
                } footer: {
                    Text("Upload and Download arrive in a later phase.")
                }
            }
            .navigationTitle("Sync")
        }
    }
}
