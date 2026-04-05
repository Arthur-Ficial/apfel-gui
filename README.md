# apfel-gui

Native macOS debug GUI for [apfel](https://github.com/Arthur-Ficial/apfel) - Apple Intelligence from the command line.

![apfel GUI Debug Inspector](screenshots/gui-chat.png)

## What is this?

A SwiftUI desktop app that talks to `apfel --serve` via HTTP. Built as a **pro debugging tool** that shows everything — raw requests, raw responses, server-side event traces, token budgets, and full SSE streams. Nothing hidden.

### Features

- **Chat interface** with streaming responses
- **Debug inspector** — raw request/response JSON, token breakdown (prompt + completion), finish reason, curl commands
- **Server-side event trace** — matched by request ID, shows context building, chunk deltas, tool detection, and finish events from the server perspective
- **Request log** with live stats (uptime, requests/min, error rate, total tokens, active requests)
- **Server status bar** — version, context window, model availability, active parameter badges
- **Model settings** — temperature, max tokens, seed, JSON response mode
- **Context settings** — 5 trimming strategies (newest-first, oldest-first, sliding-window, summarize, strict)
- **Tool calling display** — shows tool_calls in messages and debug panel
- **Typed error handling** — content policy violations, context overflow, rate limiting with specific recovery guidance
- **Speech-to-text** and **text-to-speech** (on-device)
- **Self-discussion mode** — model debates itself with dual perspectives and language support
- **Configurable connection** — works with any OpenAI-compatible server (advanced setting, hidden by default)

All inference runs **on-device** via apfel's server. This app contains no model logic — it's a pure HTTP consumer.

## Requirements

- **macOS 26+** (Tahoe) with Apple Intelligence enabled
- **Apple Silicon** (M1 or later)
- **[apfel](https://github.com/Arthur-Ficial/apfel) v0.7.7+** must be installed

## Install

### Step 1: Install apfel (the server)

```bash
brew tap Arthur-Ficial/tap
brew install apfel
```

Verify it works:

```bash
apfel --version        # should print apfel v0.7.7+
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
2. Start `apfel --serve --port 11434 --cors --debug` in the background
3. Fetch server info from `/health` and `/v1/models`
4. Open the SwiftUI window

Quitting the app automatically stops the server.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+K | Clear chat |
| Cmd+D | Toggle debug panel |
| Cmd+L | Toggle log viewer |
| Cmd+J | Open self-discussion |
| Cmd+Q | Quit |
| Enter | Send message |

## Debug Inspector

The debug inspector is the heart of apfel-gui. Select any message to see:

- **Token breakdown** — prompt tokens, completion tokens, total, with budget bar
- **Finish reason** — stop, tool_calls, length, content_filter (color-coded)
- **Server trace** — the actual events from the server: request decoding, context building, chunk deltas, tool detection, finish reason
- **curl command** — copy and paste to reproduce the exact request
- **Request JSON** — what was sent to the server
- **Response JSON** — raw SSE events, exactly as received
- **Tool calls** — function name and arguments for each tool call
- **Error type** — structured error classification with recovery guidance

## API Compatibility

apfel-gui uses the OpenAI-compatible API exposed by `apfel --serve`:

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Server status, version, context window, model availability |
| `GET /v1/models` | Model capabilities, supported/unsupported parameters |
| `POST /v1/chat/completions` | Chat (streaming + non-streaming) |
| `GET /v1/logs` | Request log with events (requires `--debug`) |
| `GET /v1/logs/stats` | Aggregate stats |

The connection can be pointed to any OpenAI-compatible server via Model Settings → Connection (Advanced).

## Related

- [apfel](https://github.com/Arthur-Ficial/apfel) - CLI + OpenAI-compatible server for Apple's on-device LLM
