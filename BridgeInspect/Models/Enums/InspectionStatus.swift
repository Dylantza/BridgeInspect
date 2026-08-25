import Foundation

enum InspectionStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case notStarted
    case completed
    case notApplicable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notStarted: "Not Started"
        case .completed: "Completed"
        case .notApplicable: "Not Applicable"
        }
    }

    /// Compact label for the status buttons in the detail sheet.
    var shortTitle: String {
        switch self {
        case .notStarted: "To Do"
        case .completed: "Done"
        case .notApplicable: "N/A"
        }
    }

    /// Single glyph shown in the table cell.
    var glyph: String {
        switch self {
        case .notStarted: "○"
        case .completed: "●"
        case .notApplicable: "–"
        }
    }
}
