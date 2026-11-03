import Foundation
import Observation
import ActivityKit

struct Note: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var createdAt = Date()
}

/// Notes live in one JSON file in the app container. The "Create & Go Live"
/// intent runs inside the app process, so no shared storage is needed.
@MainActor
@Observable
final class Store {
    static let shared = Store()
    static let liveKey = "liveNoteID"

    private(set) var notes: [Note] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveNote", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notes.json")
    }()

    private init() { load() }

    var liveNote: Note? {
        guard let raw = UserDefaults.standard.string(forKey: Store.liveKey),
              let id = UUID(uuidString: raw) else { return nil }
        return notes.first { $0.id == id }
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Note].self, from: data) else { return }
        notes = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    @discardableResult
    func add(_ text: String) -> Note? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let note = Note(text: trimmed)
        notes.insert(note, at: 0)
        save()
        return note
    }

    func update(_ note: Note, text: String) {
        guard let i = notes.firstIndex(of: note) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes[i].text = trimmed
        save()
        if liveNote?.id == note.id { Task { await LiveActivityController.go(notes[i]) } }
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        save()
        if UserDefaults.standard.string(forKey: Store.liveKey) == note.id.uuidString {
            Task { await LiveActivityController.end() }
        }
    }

    func goLive(_ note: Note) async {
        UserDefaults.standard.set(note.id.uuidString, forKey: Store.liveKey)
        await LiveActivityController.go(note)
    }

    func endLive() async {
        UserDefaults.standard.removeObject(forKey: Store.liveKey)
        await LiveActivityController.end()
    }

    /// Live Activities expire after a few hours. If the app comes back and the
    /// chosen note has no activity any more, put it back up.
    func restoreIfNeeded() async {
        guard let note = liveNote, Activity<NoteAttributes>.activities.isEmpty else { return }
        await LiveActivityController.go(note)
    }
}

enum LiveActivityController {
    static var isRunning: Bool { !Activity<NoteAttributes>.activities.isEmpty }

    static func go(_ note: Note) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = NoteAttributes.ContentState(noteID: note.id, text: String(note.text.prefix(400)), updatedAt: .now)
        let content = ActivityContent(state: state, staleDate: nil)
        let existing = Activity<NoteAttributes>.activities
        if let first = existing.first {
            await first.update(content)
            for extra in existing.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
        } else {
            _ = try? Activity.request(attributes: NoteAttributes(startedAt: .now), content: content, pushType: nil)
        }
    }

    static func end() async {
        for a in Activity<NoteAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
