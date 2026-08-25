import Foundation
import SwiftData

enum AppModelContainer {
    static let schema = Schema([
        Project.self,
        Space.self,
        Wall.self,
        Inspection.self,
        WallMedia.self,
    ])

    /// On-disk container used by the app.
    static func makeShared() -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // A container that cannot open means no local storage, which is
            // fatal for an offline-first tool. Fail loudly rather than run
            // in a state where field work silently is not saved.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    /// In-memory container for tests and previews.
    static func makeInMemory() throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }
}
