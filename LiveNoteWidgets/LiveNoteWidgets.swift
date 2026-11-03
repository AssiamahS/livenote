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
            LockScreenCard(text: context.state.text)
                .activityBackgroundTint(field)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "note.text").foregroundStyle(accent).font(.body.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: DismissLiveNoteIntent()) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.text)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "note.text").foregroundStyle(accent)
            } compactTrailing: {
                Text(context.state.text).font(.caption2).lineLimit(1).frame(maxWidth: 64)
            } minimal: {
                Image(systemName: "note.text").foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }
}

struct LockScreenCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(intent: DismissLiveNoteIntent()) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }
}
