import Foundation
import SwiftData

@Model
final class Wall {
    #Unique<Wall>([\.id])

    var id: UUID = UUID()
    var name: String = ""
    var sortIndex: Int = 0

    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: Sync metadata
    var remoteUpdatedAt: Date?
    var isDeleted: Bool = false
    var syncStateRaw: String = SyncState.local.rawValue

    var space: Space?

    @Relationship(deleteRule: .cascade, inverse: \Inspection.wall)
    var inspections: [Inspection] = []

    @Relationship(deleteRule: .cascade, inverse: \WallMedia.wall)
    var media: [WallMedia] = []

    init(name: String, sortIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = .now
        self.updatedAt = .now
    }
}

extension Wall {
    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .local }
        set { syncStateRaw = newValue.rawValue }
    }

    /// Looks up the inspection for a type. Rows are created lazily on first
    /// touch, so an undocumented wall carries no inspection records at all.
    func inspection(for type: InspectionType) -> Inspection? {
        inspections.first { !$0.isDeleted && $0.type == type }
    }

    func status(for type: InspectionType) -> InspectionStatus {
        inspection(for: type)?.status ?? .notStarted
    }

    /// iPhone-captured media, excluding tombstones, in display order.
    var activeMedia: [WallMedia] {
        media.filter { !$0.isDeleted }.sorted { $0.sortIndex < $1.sortIndex }
    }

    var photoMediaCount: Int { activeMedia.count { $0.kind == .photo } }
    var videoMediaCount: Int { activeMedia.count { $0.kind == .video } }

    var hasNote: Bool {
        guard let notes else { return false }
        return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Inspections still to do. "Not applicable" counts as resolved — the
    /// inspector has made a decision about it.
    var outstandingCount: Int {
        InspectionType.allCases.count { status(for: $0) == .notStarted }
    }

    var isComplete: Bool { outstandingCount == 0 }

    func touch() {
        updatedAt = .now
        syncState = .local
    }
}
