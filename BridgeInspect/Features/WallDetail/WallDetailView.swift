import SwiftUI
import SwiftData
import AVKit

struct WallDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let wall: Wall

    @State private var note = ""
    @State private var capturingKind: MediaKind?
    @State private var showingEdit = false
    @State private var previewItem: WallMedia?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextField("Note for this wall", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    HStack(spacing: 12) {
                        Button {
                            capturingKind = .photo
                        } label: {
                            Label("Photo", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        Button {
                            capturingKind = .video
                        } label: {
                            Label("Video", systemImage: "video")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    if wall.activeMedia.isEmpty {
                        Text("No media captured on this iPhone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(wall.activeMedia) { item in
                                thumbnail(for: item)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("iPhone Media")
                } footer: {
                    if !wall.activeMedia.isEmpty {
                        Text("\(wall.photoMediaCount) photos · \(wall.videoMediaCount) videos")
                    }
                }

                Section("Inspections") {
                    ForEach(InspectionType.allCases) { type in
                        HStack {
                            StatusGlyph(status: wall.status(for: type), size: 13)
                                .frame(width: 20)
                            Text(type.title)
                            Spacer()
                            Text(wall.status(for: type).shortTitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(wall.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { save(); dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Rename") { showingEdit = true }
                }
            }
            .onAppear { note = wall.notes ?? "" }
            .fullScreenCover(item: $capturingKind) { kind in
                CameraPicker(kind: kind) { filename, savedKind in
                    addMedia(filename: filename, kind: savedKind)
                }
                .ignoresSafeArea()
            }
            .sheet(item: $previewItem) { item in
                MediaPreview(media: item) { delete(item) }
            }
            .sheet(isPresented: $showingEdit) {
                if let space = wall.space {
                    WallEditSheet(space: space, wall: wall)
                }
            }
        }
    }

    private func thumbnail(for item: WallMedia) -> some View {
        Button {
            previewItem = item
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if item.kind == .photo,
                       let image = MediaStore.loadImage(named: item.localFilename) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .overlay {
                                Image(systemName: item.kind.symbolName)
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if item.kind == .video {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func addMedia(filename: String, kind: MediaKind) {
        let item = WallMedia(localFilename: filename, kind: kind,
                             sortIndex: wall.activeMedia.count)
        item.wall = wall
        context.insert(item)
        wall.touch()
    }

    /// Soft-delete the record, hard-delete the file. The bytes are large and,
    /// once removed by the user, are not something sync needs to restore.
    private func delete(_ item: WallMedia) {
        item.isDeleted = true
        MediaStore.delete(filename: item.localFilename)
        wall.touch()
        previewItem = nil
    }

    private func save() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue = trimmed.isEmpty ? nil : trimmed
        guard newValue != wall.notes else { return }
        wall.notes = newValue
        wall.touch()
    }
}

/// Full-size view of one captured item.
private struct MediaPreview: View {
    @Environment(\.dismiss) private var dismiss
    let media: WallMedia
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if media.kind == .video, let url = try? MediaStore.url(for: media.localFilename) {
                    VideoPlayer(player: AVPlayer(url: url))
                } else if let image = MediaStore.loadImage(named: media.localFilename) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ContentUnavailableView("Media Unavailable", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", role: .destructive, action: onDelete)
                }
            }
        }
    }
}
