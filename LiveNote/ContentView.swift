import SwiftUI
import UIKit
import ActivityKit

struct ContentView: View {
    @State private var store = Store.shared
    @State private var draft = ""
    @State private var editing: Note?
    @State private var showSetup = false
    @FocusState private var composing: Bool

    private var accent: Color { Color(red: LiveNoteBrand.accent.red, green: LiveNoteBrand.accent.green, blue: LiveNoteBrand.accent.blue) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    liveCard
                    composer
                    if !store.notes.isEmpty { history }
                }
                .padding(20)
            }
            .background(Color(red: LiveNoteBrand.background.red, green: LiveNoteBrand.background.green, blue: LiveNoteBrand.background.blue).ignoresSafeArea())
            .navigationTitle("LiveNote")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSetup = true } label: { Image(systemName: "bolt.circle") }
                }
            }
            .sheet(isPresented: $showSetup) { SetupView() }
            .sheet(item: $editing) { note in EditView(note: note) }
        }
        .tint(accent)
    }

    // MARK: live

    @ViewBuilder private var liveCard: some View {
        if store.liveNotes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nothing live").font(.headline)
                Text("Type a note below, or press the Action button once it is set up.").font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
        } else {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 8, height: 8)
                Text(store.liveNotes.count == 1 ? "ON YOUR LOCK SCREEN" : "\(store.liveNotes.count) ON YOUR LOCK SCREEN")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
                if store.liveNotes.count > 1 {
                    Button("Clear all") { Task { await store.endAll() } }.font(.caption.bold())
                }
            }
            .padding(.horizontal, 4)
            ForEach(store.liveNotes) { note in
                VStack(alignment: .leading, spacing: 10) {
                    Text(note.text).font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button { editing = note } label: { Label("Edit", systemImage: "pencil") }
                        Spacer()
                        Button { Task { await store.endLive(note) } } label: { Label("Done", systemImage: "checkmark") }
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.glass)
                }
                .padding(18)
                .glassEffect(.regular.tint(accent.opacity(0.12)), in: .rect(cornerRadius: 22))
            }
        }
    }

    // MARK: composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("What would you like your note to say?", text: $draft, axis: .vertical)
                .lineLimit(1...6)
                .focused($composing)
                .font(.body)
            Button {
                guard let note = store.add(draft) else { return }
                draft = ""
                composing = false
                Task { await store.goLive(note) }
            } label: {
                Label("Go Live", systemImage: "arrow.up.circle.fill")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: history

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(.caption.weight(.bold)).foregroundStyle(.secondary).padding(.horizontal, 4)
            ForEach(store.notes) { note in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(note.text).lineLimit(3)
                    Spacer()
                    if store.isLive(note) { Text("LIVE").font(.caption2.bold()).foregroundStyle(accent) }
                    Text(note.createdAt, format: .dateTime.month(.abbreviated).day()).font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(store.isLive(note) ? 0.08 : 0.04), in: .rect(cornerRadius: 16))
                .contentShape(.rect)
                .onTapGesture { Task { await store.goLive(note) } }
                .contextMenu {
                    Button { Task { await store.goLive(note) } } label: { Label("Go Live", systemImage: "arrow.up.circle") }
                    Button { editing = note } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { store.delete(note) } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
    }
}

struct EditView: View {
    @Environment(\.dismiss) private var dismiss
    let note: Note
    @State private var text = ""

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .navigationTitle("Edit note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Store.shared.update(note, text: text); dismiss() }
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
        .onAppear { text = note.text }
        .presentationDetents([.medium])
    }
}

struct SetupView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(LiveNoteBrand.glassKey) private var glass = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Transparent card", isOn: $glass)
                        .onChange(of: glass) { _, _ in Task { await Store.shared.restyleLive() } }
                } header: {
                    Text("Lock Screen card")
                } footer: {
                    Text("On: iOS 26 glass over your wallpaper. Off: solid dark card.")
                }
                Section("Action button, Back Tap, Lock Screen") {
                    step(1, "Open **Shortcuts**, tap **+**, search **LiveNote**, pick **Create & Go Live**.")
                    step(2, "Leave **Text** empty so it asks you each time. Expand the action and turn off **Show When Run**.")
                    step(3, "**Settings → Action Button → Shortcut** and choose it. Or **Accessibility → Touch → Back Tap**, or add a **Shortcut** control to the Lock Screen / Control Center.")
                    Button {
                        if let url = URL(string: "shortcuts://create-shortcut") { UIApplication.shared.open(url) }
                    } label: { Label("Open Shortcuts", systemImage: "arrow.up.forward.app") }
                }
                Section("Siri, no setup") {
                    Text("“Hey Siri, create a LiveNote” — new note on the Lock Screen.")
                    Text("“Hey Siri, LiveNote done” — clears the newest note. No tapping.")
                    Text("“Hey Siri, clear all my LiveNotes” — clears every card.")
                }
                Section("Good to know") {
                    Text("Up to 3 notes can be live at once; they stack on the Lock Screen and the newest one shows in the Dynamic Island. Posting a 4th drops the oldest.")
                    Text("The Dynamic Island pill shows only the first few words on every iPhone. Press and hold it to read the whole note.")
                    Text("iOS ends a Live Activity after about 8 hours. Open LiveNote, or say “Hey Siri, put my LiveNote back”.")
                }
            }
            .navigationTitle("Set up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.caption.bold()).frame(width: 22, height: 22).background(.white.opacity(0.1), in: .circle)
            Text(text)
        }
    }
}
