import SwiftUI
import SwiftData

@main
struct BridgeInspectApp: App {
    let container = AppModelContainer.makeShared()

    var body: some Scene {
        WindowGroup {
            RootView()
                #if DEBUG
                .task { SeedData.loadIfRequested(into: container.mainContext) }
                #endif
        }
        .modelContainer(container)
    }
}
