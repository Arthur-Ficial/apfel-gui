# apfel-gui - Project Instructions

## Purpose

Native macOS SwiftUI debug GUI for [apfel](https://github.com/Arthur-Ficial/apfel). Pure HTTP consumer - no model logic, no FoundationModels dependency. Works with apfel v0.8.1+.

## Install & Run

```bash
brew tap Arthur-Ficial/tap
brew install apfel-gui          # installs apfel-gui + apfel
apfel-gui                       # run
```

## Build & Install

```bash
make build                      # build release (NO version bump)
make install                    # build + install to /usr/local/bin + MCP server (NO version bump)
make version                    # print current version
swift build                     # debug build
swift run apfel-gui             # run debug build
```

`make install` auto-unlinks Homebrew apfel-gui so the dev binary takes PATH priority. `make uninstall` restores the Homebrew link.

**Version is in `.version` file** (single source of truth). Local builds (`make build`, `make install`) do NOT change the version. Only the release workflow bumps versions. Never manually edit `.version` or `Sources/BuildInfo.swift`.

## Release

```bash
./scripts/release.sh 1.1.0      # build, package, GitHub release, update Homebrew formula
```

## Architecture

```
main.swift → startGUI()
  └─ GUIApp.swift: discovers MCP servers, spawns `apfel --serve --debug --mcp ...`
      └─ GUIAppDelegate → MainWindow (SwiftUI)
          ├─ ServerStatusBar (version, context window, active params)
          ├─ ChatView + ChatViewModel ←→ APIClient (HTTP)
          ├─ DebugPanel (request/response inspector + server trace)
          ├─ LogViewer (live request log + stats)
          ├─ ModelSettingsView (temperature, max_tokens, seed, JSON mode, connection)
          ├─ ContextSettingsView (strategy picker)
          ├─ SelfDiscussionView (AI self-debate)
          ├─ STTManager (speech-to-text, on-device)
          └─ TTSManager (text-to-speech, on-device)
```

## Key Files

| File | Purpose |
|------|---------|
| `Sources/main.swift` | Entry point |
| `Sources/GUIApp.swift` | Server lifecycle, MCP discovery, NSApplication setup |
| `Sources/APIClient.swift` | HTTP client for /v1 endpoints, /health, /v1/models |
| `Sources/ChatViewModel.swift` | Observable state for chat UI, model settings, server info |
| `Sources/ChatView.swift` | Main chat interface with typed error display |
| `Sources/DebugPanel.swift` | Request/response JSON inspector + server event trace |
| `Sources/LogViewer.swift` | Live request log with stats bar and filtering |
| `Sources/MainWindow.swift` | Three-panel layout + server status bar |
| `Sources/MessageBubble.swift` | Chat message with tool calls and error badges |
| `Sources/ModelSettingsView.swift` | Temperature, max_tokens, seed, JSON mode, connection settings |
| `Sources/MCPSettingsView.swift` | MCP tool server configuration |
| `Sources/ContextSettingsView.swift` | Context strategy picker |
| `Sources/ContextStrategy.swift` | Duplicated enum from ApfelCore |
| `Sources/SelfDiscussionView.swift` | Self-discussion configuration |
| `Sources/STTManager.swift` | On-device speech-to-text |
| `Sources/TTSManager.swift` | On-device text-to-speech |
| `Sources/Helpers.swift` | printStderr utility |

## API Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Server status, version, context_window, model_available, supported_languages |
| `/v1/models` | GET | Model capabilities, supported/unsupported parameters |
| `/v1/chat/completions` | POST | Chat (streaming SSE + non-streaming), with temperature, max_tokens, seed, response_format |
| `/v1/logs` | GET | Request log with events (requires --debug) |
| `/v1/logs/stats` | GET | Aggregate stats (uptime, requests, errors, tokens, active) |

## MCP Support

- GUI auto-discovers MCP servers: bundled `mcp/debug-tools/server.py` + apfel's `mcp/calculator/server.py`
- Passes `--mcp <path>` flags when launching apfel — apfel handles all MCP logic
- GUI is a thin layer: shows tool calls, finish reasons, and server events in debug panel
- MCP settings allow adding custom server paths (saved to UserDefaults)
- `make install` copies bundled MCP server to `/usr/local/share/apfel-gui/mcp/debug-tools/`

## Notes

- `ContextStrategy` enum is duplicated from ApfelCore (13 lines) to keep this repo independent
- No external Swift package dependencies - only system frameworks
- `Info.plist` must include `NSMicrophoneUsageDescription` for STT to work
- Server launched with `--debug` flag for log endpoints to work
- Connection is configurable (Model Settings → Advanced) for use with any OpenAI-compatible server
- APIClient uses `@unchecked Sendable` with mutable baseURL/modelName for connection changes
