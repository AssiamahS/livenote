import Foundation
import ActivityKit
import AppIntents

/// What the app and the widget extension share: the shape of a live note.
struct NoteAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var noteID: UUID
        var text: String
        var updatedAt: Date
        /// true = translucent system material (iOS 26 glass), false = solid dark card
        var glass: Bool
    }
    var startedAt: Date
}

enum LiveNoteBrand {
    static let glassKey = "glassCard"
    static let liveIDsKey = "liveNoteIDs"   // [String], oldest first
    static let maxLive = 3
    static let accent = (red: 0.18, green: 0.83, blue: 0.78)
    static let background = (red: 0.05, green: 0.06, blue: 0.08)
}

/// Shared bookkeeping for which notes are live. UserDefaults is fine: every
/// intent here is a LiveActivityIntent, so it runs inside the app process.
enum LiveRegistry {
    static var ids: [String] {
        get { UserDefaults.standard.stringArray(forKey: LiveNoteBrand.liveIDsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: LiveNoteBrand.liveIDsKey) }
    }
    static func remove(_ id: String) { ids = ids.filter { $0 != id } }

    static func endActivity(noteID: String) async {
        for a in Activity<NoteAttributes>.activities where a.content.state.noteID.uuidString == noteID {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        remove(noteID)
    }

    static func endAll() async {
        for a in Activity<NoteAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
        ids = []
    }
}

/// Check mark on a card, or "Hey Siri, LiveNote done". With no note given it
/// clears the newest live note. Lives in both targets so the widget can
/// reference it; the system performs it in the app process.
struct DismissLiveNoteIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Done"
    static let description = IntentDescription("Takes a live note off the Lock Screen and the Dynamic Island. With no note chosen, clears the newest one.")
    static let openAppWhenRun = false

    @Parameter(title: "Note ID")
    var noteID: String?

    init() {}
    init(noteID: String) { self.noteID = noteID }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        if let noteID {
            await LiveRegistry.endActivity(noteID: noteID)
            return .result(dialog: "Done.")
        }
        guard let newest = LiveRegistry.ids.last else { return .result(dialog: "Nothing is live.") }
        await LiveRegistry.endActivity(noteID: newest)
        return .result(dialog: LiveRegistry.ids.isEmpty ? "Done. Lock Screen is clear." : "Done.")
    }
}

/// "Hey Siri, clear all my LiveNotes".
struct ClearAllLiveNotesIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Clear All Live Notes"
    static let description = IntentDescription("Takes every live note off the Lock Screen.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await LiveRegistry.endAll()
        return .result(dialog: "Lock Screen is clear.")
    }
}
