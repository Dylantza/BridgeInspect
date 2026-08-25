import Foundation
import SwiftData

@Model
final class Space {
    #Unique<Space>([\.id])

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

    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \Wall.space)
    var walls: [Wall] = []

    init(name: String, sortIndex: Int = 0, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.sortIndex = sortIndex
        self.notes = notes
        self.createdAt = .now
        self.updatedAt = .now
    }
}

extension Space {
    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .local }
        set { syncStateRaw = newValue.rawValue }
    }

    /// Walls excluding tombstones, in display order.
    /// The count is whatever the user created — never fixed.
    var activeWalls: [Wall] {
        walls.filter { !$0.isDeleted }.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Total inspection cells across every wall in this space.
    var totalCellCount: Int {
        activeWalls.count * InspectionType.allCases.count
    }

    var outstandingCount: Int {
        activeWalls.reduce(0) { $0 + $1.outstandingCount }
    }

    /// 0…1, for the completion bar. An empty space reads as 0, not complete.
    var completionFraction: Double {
        guard totalCellCount > 0 else { return 0 }
        return Double(totalCellCount - outstandingCount) / Double(totalCellCount)
    }

    var isComplete: Bool { totalCellCount > 0 && outstandingCount == 0 }

    func touch() {
        updatedAt = .now
        syncState = .local
    }
}
