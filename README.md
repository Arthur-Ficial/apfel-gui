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

## Requirements

- **macOS 26+** (Tahoe) with Apple Intelligence enabled
- **Apple Silicon** (M1 or later)
- **[apfel](https://github.com/Arthur-Ficial/apfel) must be installed** — apfel-gui needs it to run the server

## Install

### Step 1: Install apfel (the server)

```bash
brew tap Arthur-Ficial/tap
brew install apfel
```

Verify it works:

```bash
apfel --version        # should print apfel v0.6.x
apfel --model-info     # check Apple Intelligence is enabled
```

> **No apfel, no GUI.** apfel-gui launches `apfel --serve` as a background process. If `apfel` is not in your PATH, the GUI will not start.

### Step 2: Install apfel-gui

```bash
git clone https://github.com/Arthur-Ficial/apfel-gui.git
cd apfel-gui
make install           # builds + installs to /usr/local/bin
```

Or build without installing:

```bash
swift build -c release
swift run apfel-gui
```

### Step 3: Run

```bash
apfel-gui
```

That's it. The GUI will:
1. Find `apfel` in your PATH
2. Start `apfel --serve --port 11434 --cors` in the background
3. Wait for the server health check
4. Open the SwiftUI window

Quitting the app automatically stops the server.

## Related

- [apfel](https://github.com/Arthur-Ficial/apfel) — CLI + OpenAI-compatible server for Apple's on-device LLM
