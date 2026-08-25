import Foundation
import SwiftData

@Model
final class Inspection {
    #Unique<Inspection>([\.id])

    var id: UUID = UUID()
    var typeRaw: String = ""
    var statusRaw: String = InspectionStatus.notStarted.rawValue

    /// Deliberately unstructured for now. Structured result fields come once
    /// we have seen what inspectors actually record in the field.
    var resultText: String?

    /// Number of frames shot on the external camera. Only used by .photo.
    var frameCount: Int?

    var notes: String?
    var completedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: Sync metadata
    var remoteUpdatedAt: Date?
    var isDeleted: Bool = false
    var syncStateRaw: String = SyncState.local.rawValue

    var wall: Wall?

    init(type: InspectionType, status: InspectionStatus = .notStarted) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.statusRaw = status.rawValue
        self.createdAt = .now
        self.updatedAt = .now
    }
}

extension Inspection {
    var type: InspectionType {
        get { InspectionType(rawValue: typeRaw) ?? .hammer }
        set { typeRaw = newValue.rawValue }
    }

    var status: InspectionStatus {
        get { InspectionStatus(rawValue: statusRaw) ?? .notStarted }
        set {
            statusRaw = newValue.rawValue
            completedAt = (newValue == .completed) ? .now : nil
            touch()
        }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .local }
        set { syncStateRaw = newValue.rawValue }
    }

    func touch() {
        updatedAt = .now
        syncState = .local
    }
}
