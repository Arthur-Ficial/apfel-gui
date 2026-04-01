# apfel-gui — Project Instructions

## Purpose

Native macOS SwiftUI debug GUI for [apfel](https://github.com/Arthur-Ficial/apfel). Pure HTTP consumer — no model logic, no FoundationModels dependency.

## Build & Run

```bash
swift build -c release          # build
make install                    # build + install to /usr/local/bin
swift run apfel-gui             # run debug build
```

Requires `apfel` installed and in PATH.

## Architecture

```
main.swift → startGUI()
  └─ GUIApp.swift: spawns `apfel --serve`, waits for health check
      └─ GUIAppDelegate → MainWindow (SwiftUI)
          ├─ ChatView + ChatViewModel ←→ APIClient (HTTP)
          ├─ DebugPanel (request/response inspector)
          ├─ LogViewer (request log)
          ├─ ContextSettingsView (strategy picker)
          ├─ SelfDiscussionView (AI self-debate)
          ├─ STTManager (speech-to-text, on-device)
          └─ TTSManager (text-to-speech, on-device)
```

## Key Files

| File | Purpose |
|------|---------|
| `Sources/main.swift` | Entry point |
| `Sources/GUIApp.swift` | Server lifecycle, NSApplication setup |
| `Sources/APIClient.swift` | HTTP client for /v1 endpoints |
| `Sources/ChatViewModel.swift` | Observable state for chat UI |
| `Sources/ChatView.swift` | Main chat interface |
| `Sources/DebugPanel.swift` | Request/response JSON inspector |
| `Sources/ContextStrategy.swift` | Duplicated enum from ApfelCore |
| `Sources/Helpers.swift` | printStderr utility |

## Notes

- `ContextStrategy` enum is duplicated from ApfelCore (13 lines) to keep this repo independent
- No external Swift package dependencies — only system frameworks
- `Info.plist` must include `NSMicrophoneUsageDescription` for STT to work
