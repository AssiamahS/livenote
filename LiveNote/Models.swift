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

    private(set) var notes: [Note] = []
    /// Oldest first. Mirrors LiveRegistry so SwiftUI can observe it.
    private(set) var liveIDs: [String] = LiveRegistry.ids

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveNote", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notes.json")
    }()

    private init() { load() }

    /// Newest live note first, the way the Lock Screen stacks them.
    var liveNotes: [Note] {
        liveIDs.reversed().compactMap { id in notes.first { $0.id.uuidString == id } }
    }

    func isLive(_ note: Note) -> Bool { liveIDs.contains(note.id.uuidString) }

    func load() {
        liveIDs = LiveRegistry.ids
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
        if isLive(note) { let n = notes[i]; Task { await LiveActivityController.go(n) } }
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        save()
        if isLive(note) { Task { await endLive(note) } }
    }

    /// Adds the note to the Lock Screen (up to maxLive; the oldest drops off).
    func goLive(_ note: Note) async {
        var ids = LiveRegistry.ids.filter { $0 != note.id.uuidString }
        ids.append(note.id.uuidString)
        while ids.count > LiveNoteBrand.maxLive {
            let drop = ids.removeFirst()
            await LiveRegistry.endActivity(noteID: drop)
        }
        LiveRegistry.ids = ids
        liveIDs = ids
        await LiveActivityController.go(note)
    }

    func endLive(_ note: Note) async {
        await LiveRegistry.endActivity(noteID: note.id.uuidString)
        liveIDs = LiveRegistry.ids
    }

    func endAll() async {
        await LiveRegistry.endAll()
        liveIDs = []
    }

    /// Re-push every live note so a changed card style applies at once.
    func restyleLive() async {
        for n in liveNotes { await LiveActivityController.go(n) }
    }

    /// Live Activities expire after a few hours. If the app comes back and a
    /// chosen note has no activity any more, put it back up. Also drops
    /// registry entries whose note was deleted.
    func restoreIfNeeded() async {
        liveIDs = LiveRegistry.ids
        let running = Set(Activity<NoteAttributes>.activities.map { $0.content.state.noteID.uuidString })
        for n in liveNotes where !running.contains(n.id.uuidString) {
            await LiveActivityController.go(n)
        }
        let known = Set(notes.map { $0.id.uuidString })
        let pruned = LiveRegistry.ids.filter { known.contains($0) }
        if pruned.count != LiveRegistry.ids.count { LiveRegistry.ids = pruned; liveIDs = pruned }
    }
}

enum LiveActivityController {
    static func go(_ note: Note) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let glass = UserDefaults.standard.object(forKey: LiveNoteBrand.glassKey) as? Bool ?? true
        let state = NoteAttributes.ContentState(noteID: note.id, text: String(note.text.prefix(1500)), updatedAt: .now, glass: glass)
        let content = ActivityContent(state: state, staleDate: nil)
        let mine = Activity<NoteAttributes>.activities.filter { $0.content.state.noteID == note.id }
        if let first = mine.first {
            await first.update(content)
            for extra in mine.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
        } else {
            _ = try? Activity.request(attributes: NoteAttributes(startedAt: .now), content: content, pushType: nil)
        }
    }
}
