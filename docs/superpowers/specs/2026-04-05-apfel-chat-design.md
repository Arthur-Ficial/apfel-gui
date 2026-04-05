# apfel-chat Design Spec

**Date:** 2026-04-05
**Status:** Approved (user delegated all decisions)
**Sister project to:** apfel-gui (debug tool)

## Purpose

A super-fast, lightweight, beautiful chat client for on-device AI via apfel. ChatGPT competitor that's 100% local — no telemetry, no calling home, no cloud. Multi-chat, speech I/O, markdown rendering, professional streamlined interface. Distributed via Homebrew and Mac App Store.

**Non-goals:** Debugging features (that's apfel-gui), cloud AI providers, plugins/extensions (v1).

## Key Principles

1. **Speed** — instant launch, instant response rendering, zero lag on scroll/input
2. **Privacy** — 100% local, no analytics, no network calls except localhost apfel
3. **Simplicity** — one settings panel, great defaults, zero config to start chatting
4. **Beauty** — clean, light, professional. Wikipedia-style: white backgrounds, high contrast
5. **Modularity** — protocol-driven, every component testable in isolation
6. **No "Apple"** — say "on-device", "your Mac", "Foundation Models on your Mac"

## Architecture

### Layer Diagram

```
SwiftUI Views (thin, declarative)
    ↓ @Bindable
ViewModels (@Observable, @MainActor)
    ↓ protocol references
Services (protocols + implementations)
    ↓
System Frameworks (URLSession, Speech, AVFoundation, libsqlite3)
```

### Protocols (TDD seam — every service has a protocol)

```swift
protocol ChatService: Sendable {
    func send(messages: [Message], settings: ModelSettings) -> AsyncThrowingStream<StreamDelta, Error>
    func healthCheck() async throws -> ServerHealth
    func models() async throws -> [ModelInfo]
}

protocol SpeechInput {
    var isListening: Bool { get }
    var transcript: String { get }
    func startListening() async throws
    func stopListening() -> String
}

protocol SpeechOutput {
    var isSpeaking: Bool { get }
    func speak(_ text: String) async
    func stop()
}

protocol ChatPersistence {
    func createConversation(title: String) async throws -> Conversation
    func listConversations() async throws -> [Conversation]
    func deleteConversation(id: String) async throws
    func addMessage(_ msg: Message, to conversationId: String) async throws
    func messages(for conversationId: String) async throws -> [Message]
    func updateConversation(_ conv: Conversation) async throws
    func search(query: String) async throws -> [Message]
}
```

### Data Models

```swift
struct Conversation: Identifiable, Codable {
    let id: String          // UUID
    var title: String       // Auto-generated from first message, editable
    var systemPrompt: String?
    let createdAt: Date
    var updatedAt: Date
    var modelSettings: ModelSettings?  // Per-conversation overrides
}

struct Message: Identifiable, Codable {
    let id: String
    let conversationId: String
    let role: Role          // .user, .assistant, .system
    var content: String
    let timestamp: Date
    var tokenCount: Int?
    var durationMs: Int?
    var isStreaming: Bool
}

enum Role: String, Codable { case user, assistant, system }

struct ModelSettings: Codable {
    var temperature: Double?     // nil = server default
    var maxTokens: Int?
    var seed: Int?
    var jsonMode: Bool
}

struct ServerHealth: Codable {
    let status: String
    let version: String?
    let contextWindow: Int?
    let modelAvailable: Bool
    let supportedLanguages: [String]?
}

struct StreamDelta {
    let text: String?
    let finishReason: String?
    let usage: TokenUsage?
}
```

### Services

**ApfelChatService** — HTTP client to apfel server
- Pure URLSession, streaming via `bytes(for:)`
- SSE parsing (same proven pattern from apfel-gui)
- Configurable base URL (default: localhost)
- Sends: temperature, max_tokens, seed, response_format
- No static mutable state (unlike apfel-gui — each instance is independent)

**SQLitePersistence** — Chat storage via raw libsqlite3 C API
- No external dependencies (SQLite ships with macOS)
- Database: `~/Library/Application Support/apfel-chat/chats.db`
- Tables: conversations, messages
- Indices on: conversation_id, timestamp, content (FTS5 for search)
- WAL mode for concurrent read/write
- Migrations via version table

**OnDeviceSpeechInput** — STT via SFSpeechRecognizer
- On-device recognition (macOS 26+)
- Permission handling with System Settings deep links
- Real-time partial results

**OnDeviceSpeechOutput** — TTS via AVSpeechSynthesizer
- Smart voice selection (best available for language)
- Default: English, best Siri voice
- Configurable in Settings

### ViewModels

**ConversationListViewModel**
- conversations: [Conversation] — sorted by updatedAt desc
- selectedId: String? — drives navigation
- CRUD: create, rename, delete conversations
- Search across all messages

**ChatViewModel**
- messages: [Message] — for active conversation
- currentInput: String
- isStreaming: Bool
- send() — appends user message, streams response, persists both
- Integrates STT (mic button) and TTS (auto-speak responses)
- Handles errors gracefully (connection lost, server busy)

**SettingsViewModel**
- Global defaults: temperature, maxTokens, language, voice
- Connection: base URL, model name, port
- Speech: enable/disable TTS auto-speak, STT language
- Persisted to UserDefaults

### Views

**App Structure:**
```
ApfelChatApp (@main, SwiftUI App)
├─ NavigationSplitView
│  ├─ Sidebar: ConversationListView
│  │  ├─ New Chat button
│  │  ├─ Search bar
│  │  └─ Conversation rows (title, date, preview)
│  └─ Detail: ChatView
│     ├─ Message list (LazyVStack + ScrollViewReader)
│     │  └─ MessageBubble (markdown rendered)
│     ├─ Streaming indicator
│     └─ InputBar
│        ├─ Text field (multi-line, submit on Enter)
│        ├─ Mic button (STT toggle)
│        ├─ Speaker toggle (TTS on/off)
│        └─ Send button
├─ Settings (sheet)
│  ├─ General: temperature, max tokens, language
│  ├─ Speech: voice selection, auto-speak toggle
│  └─ Advanced: server URL, port, model name
└─ Toolbar: Settings gear, New Chat
```

**Design Language:**
- Light theme: white background (#FFFFFF), dark text (#1a1a1a)
- Subtle gray sidebar (#F5F5F5)
- Accent color: system blue (minimal use)
- User messages: right-aligned, light blue bubble
- Assistant messages: left-aligned, white bubble with subtle border
- Monospace for code blocks, system font for everything else
- No gradients, no shadows, no decorative elements
- Compact spacing, high information density

**Markdown Rendering:**
- Native AttributedString (macOS 26+ has good markdown support)
- Code blocks with syntax highlighting (basic — keyword coloring via regex)
- Inline code, bold, italic, links, lists, headers
- JSON: auto-detect and pretty-print with monospace
- Tables: rendered as aligned monospace (simple, fast)
- LaTeX: not v1 (can add later)

### Server Lifecycle

**Strategy: Auto-manage apfel server, zero config**

1. On launch: check if apfel is running on any known port (11434, 11435, 11440-11449)
2. If found: connect to existing server
3. If not found: spawn `apfel --serve --port <first-available> --cors`
4. No `--debug` flag (not a debug tool — saves overhead)
5. No MCP servers (chat client, not debug tool)
6. On quit: terminate spawned server (if we spawned it)
7. Health check polling: every 200ms during startup, 30s heartbeat after

**Port selection:**
```swift
func findAvailablePort(startingAt: Int = 11440) -> Int
// Try bind to port, if taken increment, max 10 attempts
```

### App Store Considerations

- SwiftUI `@main` entry point (required for App Store)
- App Sandbox enabled (network: localhost only, files: app container + user-selected)
- Info.plist: NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription
- No private APIs, no entitlements beyond standard
- Hardened runtime
- Versioning: semantic (1.0.0)
- Bundle ID: `com.fullstackoptimization.apfel-chat`
- Category: Productivity
- Requires: macOS 26+, Apple Silicon

### Homebrew Distribution

- Same pattern as apfel-gui: `brew tap Arthur-Ficial/tap && brew install apfel-chat`
- Depends on `arthur-ficial/tap/apfel`
- Release script generates formula + GitHub release
- Binary is standalone (no .app bundle for brew — only for App Store)

### Testing Strategy (TDD-First)

**Protocol mocks for every service:**
```swift
class MockChatService: ChatService { ... }
class MockPersistence: ChatPersistence { ... }
class MockSpeechInput: SpeechInput { ... }
class MockSpeechOutput: SpeechOutput { ... }
```

**Test targets:**
1. **ApfelChatTests** — unit tests
   - ChatViewModel: send, receive, stream, error handling, history
   - ConversationListViewModel: CRUD, search, sorting
   - SettingsViewModel: persistence, defaults
   - SQLitePersistence: create, read, update, delete, search, migrations
   - ApfelChatService: request building, SSE parsing, error handling
   - Message rendering: markdown → AttributedString
   - Port finding: conflict detection

2. **Test approach:**
   - Every public method tested
   - ViewModels tested via mock services (no network, no disk)
   - Persistence tested against in-memory SQLite (`:memory:`)
   - SSE parsing tested with fixture data
   - No UI tests in v1 (SwiftUI views are thin enough to verify visually)

### File Structure

```
apfel-chat/
├── Package.swift
├── CLAUDE.md                    # Hardcore project instructions
├── Makefile
├── Info.plist
├── scripts/
│   └── release.sh
├── Sources/
│   ├── App/
│   │   ├── ApfelChatApp.swift   # @main entry, server lifecycle
│   │   └── ServerManager.swift  # Find/spawn/connect to apfel
│   ├── Models/
│   │   ├── Conversation.swift
│   │   ├── Message.swift
│   │   ├── ModelSettings.swift
│   │   └── ServerHealth.swift
│   ├── Protocols/
│   │   ├── ChatService.swift
│   │   ├── SpeechInput.swift
│   │   ├── SpeechOutput.swift
│   │   └── ChatPersistence.swift
│   ├── Services/
│   │   ├── ApfelChatService.swift    # HTTP + SSE client
│   │   ├── SQLitePersistence.swift   # Raw libsqlite3
│   │   ├── OnDeviceSpeechInput.swift # STT
│   │   └── OnDeviceSpeechOutput.swift # TTS
│   ├── ViewModels/
│   │   ├── ChatViewModel.swift
│   │   ├── ConversationListViewModel.swift
│   │   └── SettingsViewModel.swift
│   └── Views/
│       ├── ConversationListView.swift
│       ├── ChatView.swift
│       ├── MessageBubble.swift
│       ├── InputBar.swift
│       ├── SettingsPanel.swift
│       └── MarkdownRenderer.swift
├── Tests/
│   └── ApfelChatTests/
│       ├── Mocks/
│       │   ├── MockChatService.swift
│       │   ├── MockPersistence.swift
│       │   ├── MockSpeechInput.swift
│       │   └── MockSpeechOutput.swift
│       ├── ChatViewModelTests.swift
│       ├── ConversationListViewModelTests.swift
│       ├── SettingsViewModelTests.swift
│       ├── SQLitePersistenceTests.swift
│       ├── ApfelChatServiceTests.swift
│       ├── SSEParserTests.swift
│       ├── MarkdownRendererTests.swift
│       └── ServerManagerTests.swift
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-04-05-apfel-chat-design.md
```

### AI Controllability

- `--api` flag launches a control server (same pattern as apfel-gui)
- JSON API: create conversation, send message, list conversations, get messages
- Enables AI-first automation and testing
- Port: 11441 (control), separate from apfel server

### AI Debuggability

- Structured logging to stderr (not debug panel — that's apfel-gui's job)
- Every API call logged with request/response timing
- `--verbose` flag for detailed SSE stream logging
- Errors include full context (URL, status code, response body)

## Out of Scope (v1)

- Image/file attachments
- Multiple AI providers (only apfel/on-device)
- Plugin system
- LaTeX rendering
- Export/import conversations
- Themes (light only)
- iOS/iPadOS version
