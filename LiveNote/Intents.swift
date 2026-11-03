import AppIntents

/// The whole point of the app: run from the Action button, Back Tap, a Lock
/// Screen control or Siri, type the note, and it is on the Lock Screen
/// without the app ever opening.
struct CreateAndGoLiveIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Create & Go Live"
    static let description = IntentDescription(
        "Saves a note and puts it on your Lock Screen and Dynamic Island.",
        categoryName: "Notes")
    static let openAppWhenRun = false

    @Parameter(title: "Text", inputOptions: String.IntentInputOptions(multiline: true),
               requestValueDialog: "What would you like your note to say?")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Go live with \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let note = Store.shared.add(text) else {
            throw $text.needsValueError("What would you like your note to say?")
        }
        await Store.shared.goLive(note)
        return .result(dialog: "On your Lock Screen.")
    }
}

/// Puts the most recent note back up (Live Activities time out after a few hours).
struct GoLiveAgainIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Go Live With Last Note"
    static let description = IntentDescription("Puts your most recent note back on the Lock Screen.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let note = Store.shared.liveNote ?? Store.shared.notes.first else {
            return .result(dialog: "No notes yet.")
        }
        await Store.shared.goLive(note)
        return .result(dialog: "On your Lock Screen.")
    }
}

struct LiveNoteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateAndGoLiveIntent(),
            phrases: [
                "Create a \(.applicationName)",
                "Put a note on my lock screen with \(.applicationName)",
                "New \(.applicationName)",
            ],
            shortTitle: "Create & Go Live",
            systemImageName: "note.text.badge.plus")
        AppShortcut(
            intent: DismissLiveNoteIntent(),
            phrases: ["Clear my \(.applicationName)", "Take \(.applicationName) off my lock screen"],
            shortTitle: "Take Off Lock Screen",
            systemImageName: "checkmark.circle")
    }
}
