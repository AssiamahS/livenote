import Foundation
import ActivityKit
import AppIntents

/// The one thing the app and the widget extension share: what a live note looks like.
struct NoteAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var noteID: UUID
        var text: String
        var updatedAt: Date
    }
    var startedAt: Date
}

enum LiveNoteBrand {
    static let accent = (red: 0.18, green: 0.83, blue: 0.78)
    static let background = (red: 0.05, green: 0.06, blue: 0.08)
}

/// Runs when the check mark on the Lock Screen card is tapped. Lives in both
/// targets so the widget can reference it; the system performs it in the app process.
struct DismissLiveNoteIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Take Note Off Lock Screen"
    static let description = IntentDescription("Ends the note that is live on the Lock Screen and in the Dynamic Island.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        for activity in Activity<NoteAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        UserDefaults.standard.removeObject(forKey: "liveNoteID")
        return .result()
    }
}
