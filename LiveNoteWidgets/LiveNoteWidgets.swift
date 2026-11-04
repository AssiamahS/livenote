import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

@main
struct LiveNoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        NoteLiveActivity()
    }
}

private let accent = Color(red: LiveNoteBrand.accent.red, green: LiveNoteBrand.accent.green, blue: LiveNoteBrand.accent.blue)
private let field = Color(red: LiveNoteBrand.background.red, green: LiveNoteBrand.background.green, blue: LiveNoteBrand.background.blue)

struct NoteLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NoteAttributes.self) { context in
            LockScreenCard(text: context.state.text, noteID: context.state.noteID.uuidString, glass: context.state.glass)
                .activityBackgroundTint(context.state.glass ? nil : field)
                .activitySystemActionForegroundColor(context.state.glass ? .primary : .white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "note.text").foregroundStyle(accent).font(.body.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: DismissLiveNoteIntent(noteID: context.state.noteID.uuidString)) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let t = NoteTable.parse(context.state.text) {
                        NoteTableView(table: t, maxRows: 6, tint: .white)
                    } else {
                        Text(context.state.text)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } compactLeading: {
                Image(systemName: "note.text").foregroundStyle(accent)
            } compactTrailing: {
                // iOS caps this region at roughly a dozen characters on every model;
                // press and hold the island for the full note.
                Text(NoteTable.parse(context.state.text)?.compactLabel ?? context.state.text)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: 110, alignment: .leading)
            } minimal: {
                Image(systemName: "note.text").foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }
}

struct LockScreenCard: View {
    let text: String
    let noteID: String
    var glass = true

    var body: some View {
        let table = NoteTable.parse(text)
        HStack(alignment: .top, spacing: 12) {
            if let table {
                NoteTableView(table: table, maxRows: 8, tint: glass ? .primary : .white)
            } else {
                Text(text)
                    .font(.body.weight(.medium))
                    .foregroundStyle(glass ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(intent: DismissLiveNoteIntent(noteID: noteID)) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, table == nil ? 16 : 10)
    }
}
