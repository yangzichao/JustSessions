import SwiftUI

@main
struct JustSessionsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // The sidebar and detail colors run up behind the traffic lights instead of under a gray title bar.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
    }
}
