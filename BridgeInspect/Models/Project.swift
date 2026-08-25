import Foundation
import SwiftData

@Model
final class Project {
    #Unique<Project>([\.id])

    var id: UUID = UUID()
    var name: String = ""
    var bridgeIdentifier: String?
    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: Sync metadata
    var remoteUpdatedAt: Date?
    var isDeleted: Bool = false
    var syncStateRaw: String = SyncState.local.rawValue

    @Relationship(deleteRule: .cascade, inverse: \Space.project)
    var spaces: [Space] = []

    init(name: String, bridgeIdentifier: String? = nil, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.bridgeIdentifier = bridgeIdentifier
        self.notes = notes
        self.createdAt = .now
        self.updatedAt = .now
    }
}

extension Project {
    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .local }
        set { syncStateRaw = newValue.rawValue }
    }

    /// Spaces excluding tombstones, in display order.
    var activeSpaces: [Space] {
        spaces.filter { !$0.isDeleted }.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Marks the record dirty. Call after every user edit.
    func touch() {
        updatedAt = .now
        syncState = .local
    }
}
