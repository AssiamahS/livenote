# LiveNote

Type a note, it sits on your Lock Screen and in the Dynamic Island until you clear it.
Press the Action button, type, done. The app never has to open.

Install (registered iPhones): https://assiamahs.github.io/livenote/install.html

## Set up the Action button

1. Shortcuts → **+** → search **LiveNote** → **Create & Go Live**.
2. Leave **Text** empty so it asks each time. Expand the action and turn off **Show When Run**.
3. Settings → **Action Button** → Shortcut → pick it. Back Tap, Control Center and a Lock Screen control work the same way.

Siri works without setup: "create a LiveNote", "clear my LiveNote".

## How it works

- `CreateAndGoLiveIntent` is a `LiveActivityIntent`, so Shortcuts runs it in the background and it can start the Live Activity without bringing the app forward.
- The note is an ActivityKit Live Activity (`NoteAttributes`), rendered by the widget extension for the Lock Screen and the Dynamic Island. The check mark on the card runs `DismissLiveNoteIntent`.
- Notes are stored in a JSON file in the app container. No account, no network.
- iOS ends Live Activities after about 8 hours; opening the app or running **Go Live With Last Note** puts it back.

## Build

XcodeGen + CI only. `project.yml` is the source of truth. Push to `main` and the `iOS` workflow compiles, archives unsigned, cloud-signs an ad hoc IPA and publishes the install page to GitHub Pages.
