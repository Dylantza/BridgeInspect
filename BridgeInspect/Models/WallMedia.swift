import Foundation
import SwiftData

/// Photos and videos captured on the iPhone itself, stored as files on disk.
/// Distinct from the PHOTO and CLOSE columns, which only record that a shot
/// was taken on the external DSLR/mirrorless body.
@Model
final class WallMedia {
    #Unique<WallMedia>([\.id])

    var id: UUID = UUID()

    /// Relative filename only. Absolute paths break when iOS relocates the app
    /// container, so the directory is resolved at runtime by MediaStore.
    var localFilename: String = ""

    var kindRaw: String = MediaKind.photo.rawValue
    var capturedAt: Date = Date()
    var caption: String?
    var sortIndex: Int = 0

    // MARK: Sync metadata
    var remoteStoragePath: String?
    var isUploaded: Bool = false
    var isDeleted: Bool = false

    var wall: Wall?

    init(localFilename: String, kind: MediaKind, sortIndex: Int = 0) {
        self.id = UUID()
        self.localFilename = localFilename
        self.kindRaw = kind.rawValue
        self.sortIndex = sortIndex
        self.capturedAt = .now
    }
}

extension WallMedia {
    var kind: MediaKind {
        get { MediaKind(rawValue: kindRaw) ?? .photo }
        set { kindRaw = newValue.rawValue }
    }
}

enum MediaKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case photo
    case video

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .photo: "photo"
        case .video: "video"
        }
    }
}
