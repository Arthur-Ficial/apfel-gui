# apfel-gui

Native macOS debug GUI for [apfel](https://github.com/Arthur-Ficial/apfel) — Apple Intelligence from the command line.

![apfel GUI Debug Inspector](screenshots/gui-chat.png)

## What is this?

A SwiftUI desktop app that talks to `apfel --serve` via HTTP. It provides:

- **Chat interface** with streaming responses
- **Debug inspector** showing raw request/response JSON, token counts, and SSE events
- **Request log** with timing and curl commands for every API call
- **Context settings** to switch between trimming strategies
- **Speech-to-text** and **text-to-speech** (on-device)
- **Self-discussion mode** where the model debates itself

All inference runs **on-device** via apfel's server. This app contains no model logic — it's a pure HTTP consumer.

## Prerequisites

- **macOS 26+** (Tahoe) with Apple Intelligence enabled
- **apfel** installed and in PATH: `brew install Arthur-Ficial/tap/apfel`

## Build & Install

```bash
# Build
swift build -c release

# Install to /usr/local/bin
make install

# Or just run directly
swift run apfel-gui
```

## How it works

1. `apfel-gui` finds `apfel` in your PATH
2. Spawns `apfel --serve --port 11434 --cors` as a background process
3. Waits for the server health check to pass
4. Opens the SwiftUI window
5. All chat goes through `http://localhost:11434/v1/chat/completions`
6. Quitting the app terminates the server

## Related

- [apfel](https://github.com/Arthur-Ficial/apfel) — CLI + OpenAI-compatible server for Apple's on-device LLM
