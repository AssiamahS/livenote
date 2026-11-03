import SwiftUI

@main
struct LiveNoteApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Store.shared.load()
                Task { await Store.shared.restoreIfNeeded() }
            }
        }
    }
}
