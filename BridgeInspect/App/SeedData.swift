#if DEBUG
import Foundation
import SwiftData

/// Debug-only sample data, loaded when the app launches with -seedData.
/// Never compiled into a release build.
enum SeedData {
    @MainActor
    static func loadIfRequested(into context: ModelContext) {
        guard CommandLine.arguments.contains("-seedData") else { return }

        let existing = try? context.fetch(FetchDescriptor<Project>())
        guard existing?.isEmpty ?? true else { return }

        let project = Project(name: "Bridge A", bridgeIdentifier: "BR-A-2026")
        context.insert(project)

        // Deliberately uneven wall counts per space.
        let layout: [(String, Int)] = [
            ("Space 01", 4),
            ("Space 02", 9),
            ("Space 03", 3),
        ]

        for (spaceIndex, (spaceName, wallCount)) in layout.enumerated() {
            let space = Space(name: spaceName, sortIndex: spaceIndex)
            space.project = project
            context.insert(space)

            // A few sample notes so the NOTE column shows both states.
            let notes = [
                "Crack near the north joint, ~30cm.",
                "Surface spalling around the anchor plate.",
                "Water staining below the seam.",
            ]

            for wallIndex in 0..<wallCount {
                let wall = Wall(name: "W\(wallIndex + 1)", sortIndex: wallIndex)
                if wallIndex % 3 == 0 {
                    wall.notes = notes[(spaceIndex + wallIndex) % notes.count]
                }
                wall.space = space
                context.insert(wall)

                // Vary statuses so the table shows all three glyphs.
                for (typeIndex, type) in InspectionType.allCases.enumerated() {
                    let status: InspectionStatus
                    switch (wallIndex * 3 + typeIndex * 5) % 7 {
                    case 0, 1, 2: status = .completed
                    case 3, 4:    status = .notStarted
                    default:      status = .notApplicable
                    }
                    guard status != .notStarted else { continue }
                    let inspection = Inspection(type: type, status: status)
                    if type.tracksFrameCount, status == .completed {
                        inspection.frameCount = 4 + (wallIndex % 5)
                    }
                    inspection.wall = wall
                    context.insert(inspection)
                }
            }
        }

        try? context.save()
    }
}
#endif
