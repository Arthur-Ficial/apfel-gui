# apfel-gui

Native macOS debug GUI for [apfel](https://github.com/Arthur-Ficial/apfel) - Apple Intelligence from the command line.

![apfel GUI Debug Inspector](screenshots/gui-chat.png)

## What is this?

A SwiftUI desktop app that talks to `apfel --serve` via HTTP. Built as a **pro debugging tool** that shows everything: raw requests, raw responses, full MCP JSON-RPC protocol data, server-side event traces, token budgets, and SSE streams. Nothing hidden, nothing dumbed down.

### Features

- **Chat interface** with streaming responses
- **Debug inspector** with raw request/response JSON, token breakdown (prompt + completion), finish reason, curl commands
- **Full MCP debugging** with raw JSON-RPC request and response for every tool call, auto-discovered MCP servers, configurable via settings
- **Server-side event trace** matched by request ID: context building, chunk deltas, MCP tool execution, finish events
- **Request log** with live stats (uptime, requests/min, error rate, total tokens, active requests)
- **Server status bar** showing version, context window, model availability, MCP server count, active parameter badges
- **Model settings** for temperature, max tokens, seed, JSON response mode
- **Context settings** with 5 trimming strategies (newest-first, oldest-first, sliding-window, summarize, strict)
- **Typed error handling** for content policy violations, context overflow, rate limiting with recovery guidance
- **Speech-to-text** and **text-to-speech** (on-device)
- **Self-discussion mode** where the model debates itself with dual perspectives and language support
- **Configurable connection** to any OpenAI-compatible server (advanced setting)

All inference runs **on-device** via apfel's server. This app contains no model logic. It is a pure HTTP consumer.

## Requirements

- **macOS 26+** (Tahoe) with Apple Intelligence enabled
- **Apple Silicon** (M1 or later)
- **[apfel](https://github.com/Arthur-Ficial/apfel) v0.8.1+** must be installed

## Install

### Step 1: Install apfel (the server)

```bash
brew tap Arthur-Ficial/tap
brew install apfel
```

Verify it works:

```bash
apfel --version        # should print apfel v0.8.1+
apfel --model-info     # check Apple Intelligence is enabled
```

> **No apfel, no GUI.** apfel-gui launches `apfel --serve` as a background process. If `apfel` is not in your PATH, the GUI will not start.

### Step 2: Install apfel-gui

```bash
git clone https://github.com/Arthur-Ficial/apfel-gui.git
cd apfel-gui
make install           # builds + installs to /usr/local/bin + MCP server
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
2. Auto-discover MCP servers (bundled debug-tools + apfel's calculator if found)
3. Start `apfel --serve --port 11438 --cors --debug --mcp <servers>` in the background
4. Fetch server info from `/health` and `/v1/models`
5. Open the SwiftUI window

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

- **Token breakdown** with prompt tokens, completion tokens, total, and context budget bar
- **Finish reason** color-coded: stop, tool_calls, length, content_filter
- **MCP Request** as full JSON-RPC `tools/call` with method, name, and arguments
- **MCP Response** as full JSON-RPC result with content text and isError flag
- **MCP Events** showing auto-execution status and finish reason
- **Server trace** with the actual events from the server: request decoding, context building, chunk deltas, MCP tool execution, finish reason
- **curl command** to reproduce the exact request
- **Request JSON** showing what was sent to the server
- **Response JSON** with raw SSE events exactly as received
- **Error type** with structured error classification and recovery guidance

## MCP Tool Debugging

apfel-gui launches `apfel --serve` with `--mcp` flags. apfel handles all MCP logic: tool discovery, injection into chat completions, tool call detection, auto-execution via JSON-RPC, and re-prompting with results. The GUI shows the full raw protocol data.

**Default servers (auto-discovered):**
- **debug-tools** (bundled) with `debug_echo`, `timestamp`, `system_info` tools
- **calculator** (from apfel repo, if found) with `add`, `subtract`, `multiply`, `divide`, `sqrt`, `power`, `round_number`

**What the debug panel shows for each MCP tool call:**
```
MCP Request (JSON-RPC tools/call)
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "multiply",
    "arguments": { "a": 247, "b": 83 }
  }
}

MCP Response (JSON-RPC result)
{
  "jsonrpc": "2.0",
  "result": {
    "content": [{ "type": "text", "text": "20501" }],
    "isError": false
  }
}
```

**Adding custom MCP servers:** Open MCP settings (toolbar) and add a path to any MCP server (.py script or executable). Changes require restarting apfel-gui.

## API Compatibility

apfel-gui uses the OpenAI-compatible API exposed by `apfel --serve`:

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Server status, version, context window, model availability |
| `GET /v1/models` | Model capabilities, supported/unsupported parameters |
| `POST /v1/chat/completions` | Chat (streaming + non-streaming) with MCP tool auto-execution |
| `GET /v1/logs` | Request log with MCP events (requires `--debug`) |
| `GET /v1/logs/stats` | Aggregate stats |

The GUI uses port 11438 by default (different from apfel's default 11434) to avoid collisions.

The connection can be pointed to any OpenAI-compatible server via Model Settings and Connection (Advanced).

## Related

- [apfel](https://github.com/Arthur-Ficial/apfel) - CLI + OpenAI-compatible server for Apple's on-device LLM
