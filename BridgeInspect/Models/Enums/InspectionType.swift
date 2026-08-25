import Foundation

/// The documentation categories tracked for every wall.
/// Stored as raw strings so adding a type later is a data change, not a migration.
enum InspectionType: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Whether the DSLR/mirrorless shot was taken. Photos are captured on a
    /// separate camera body — the app only records that it happened.
    case photo
    /// Close-up detail shot, also taken on the external camera.
    case closeup
    case hammer
    case sensor
    case trimble
    case gpr
    case ultrasonic

    var id: String { rawValue }

    /// Full name, used in the detail sheet.
    var title: String {
        switch self {
        case .photo: "Wall Photos"
        case .closeup: "Close-Up"
        case .hammer: "Hammer"
        case .sensor: "Sensor"
        case .trimble: "Trimble"
        case .gpr: "GPR"
        case .ultrasonic: "Ultrasonic"
        }
    }

    /// Abbreviated name for the table column header.
    var shortTitle: String {
        switch self {
        case .photo: "PHOTO"
        case .closeup: "C-UP"
        case .hammer: "HAM"
        case .sensor: "SEN"
        case .trimble: "TRIM"
        case .gpr: "GPR"
        case .ultrasonic: "ULT"
        }
    }

    /// Column order in the space table.
    var sortIndex: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    /// Types that also record a numeric count in their detail sheet.
    var tracksFrameCount: Bool { self == .photo || self == .closeup }
}
