import Foundation
import SwiftData

/// Inspections are created lazily the first time a cell is touched, so a wall
/// costs nothing until it is actually documented.
enum InspectionResolver {
    static func resolve(
        wall: Wall,
        type: InspectionType,
        context: ModelContext
    ) -> Inspection {
        if let existing = wall.inspection(for: type) {
            return existing
        }
        let created = Inspection(type: type)
        created.wall = wall
        context.insert(created)
        return created
    }
}
