# apfel-chat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a super-fast, lightweight, 100% local chat client for on-device AI via apfel, with multi-chat, speech I/O, markdown rendering, and a clean professional interface.

**Architecture:** Protocol-driven SwiftUI app. Every service (chat HTTP, persistence, speech) has a protocol with mock implementations for TDD. Views are thin declarative layers over @Observable ViewModels. SQLite via raw libsqlite3 C API for chat persistence. SSE streaming for real-time responses.

**Tech Stack:** Swift 6.3, SwiftUI, macOS 26+, URLSession (SSE streaming), libsqlite3 (raw C), SFSpeechRecognizer (STT), AVSpeechSynthesizer (TTS), no external dependencies.

---

### Task 1: Project Scaffold

**Files:**
- Create: `/Users/arthurficial/dev/apfel-chat/Package.swift`
- Create: `/Users/arthurficial/dev/apfel-chat/CLAUDE.md`
- Create: `/Users/arthurficial/dev/apfel-chat/Info.plist`
- Create: `/Users/arthurficial/dev/apfel-chat/Makefile`
- Create: `/Users/arthurficial/dev/apfel-chat/.gitignore`

- [ ] **Step 1: Create the project directory and git repo**

```bash
mkdir -p /Users/arthurficial/dev/apfel-chat
cd /Users/arthurficial/dev/apfel-chat
git init
```

- [ ] **Step 2: Create Package.swift**

```swift
// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "apfel-chat",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "apfel-chat",
            path: "Sources",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "./Info.plist",
                ])
            ]
        ),
        .testTarget(
            name: "ApfelChatTests",
            dependencies: ["apfel-chat"],
            path: "Tests"
        ),
    ]
)
```

- [ ] **Step 3: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>apfel-chat</string>
    <key>CFBundleIdentifier</key>
    <string>com.fullstackoptimization.apfel-chat</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>apfel-chat needs microphone access for voice input (speech-to-text).</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>apfel-chat needs speech recognition access for voice input.</string>
</dict>
</plist>
```

- [ ] **Step 4: Create Makefile**

```makefile
PREFIX ?= /usr/local
BINARY_NAME = apfel-chat

.PHONY: build install clean test

build:
	swift build -c release

test:
	swift test

install: build
	@mkdir -p $(PREFIX)/bin
	@cp .build/release/$(BINARY_NAME) $(PREFIX)/bin/$(BINARY_NAME)
	@echo "Installed $(BINARY_NAME) to $(PREFIX)/bin/$(BINARY_NAME)"

clean:
	swift package clean
	rm -rf .build
```

- [ ] **Step 5: Create .gitignore**

```
.build/
.swiftpm/
*.xcodeproj
*.xcworkspace
DerivedData/
.DS_Store
```

- [ ] **Step 6: Create CLAUDE.md**

```markdown
# apfel-chat - Project Instructions

## Purpose

Super-fast, lightweight, 100% local chat client for on-device AI via apfel.
Multi-chat, speech I/O, markdown rendering. ChatGPT competitor — fully private.
Sister project to apfel-gui (debug tool). This is the consumer chat client.

## Language Rules

NEVER use the word "Apple" in user-visible strings. Use instead:
- "on-device" / "your Mac" / "Foundation Models on your Mac"
- "private AI" / "local AI"

## Install & Run

```bash
brew tap Arthur-Ficial/tap
brew install apfel-chat
apfel-chat
```

## Build from source

```bash
swift build -c release
make install
swift test              # run all tests
swift run apfel-chat    # run debug build
```

## Architecture

Protocol-driven, TDD-first. Every service has a protocol + mock for testing.

```
Sources/
├── App/              # Entry point, server lifecycle
├── Models/           # Data types (Conversation, Message, etc.)
├── Protocols/        # Service protocols (ChatService, Persistence, Speech)
├── Services/         # Real implementations (HTTP, SQLite, Speech)
├── ViewModels/       # @Observable state management
└── Views/            # SwiftUI views (thin, declarative)

Tests/
├── Mocks/            # Mock service implementations
└── *Tests.swift      # Unit tests for every component
```

## Key Design Decisions

- **No external dependencies** — only system frameworks + libsqlite3
- **Protocol-driven** — every service behind a protocol for TDD
- **SQLite via raw C API** — no ORM, no SwiftData, fast and simple
- **SwiftUI @main** — App Store compatible, no NSApplication wrapper
- **SSE streaming** — URLSession.bytes for real-time token streaming
- **apfel under the hood** — spawns `apfel --serve` or connects to existing

## API Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Server status, version, model availability |
| `/v1/models` | GET | Model info and capabilities |
| `/v1/chat/completions` | POST | Chat (streaming SSE) |

## Ports

- apfel server: 11440-11449 (auto-selects first available)
- API control server: 11441 (when --api flag used)

## Testing

```bash
swift test                                    # all tests
swift test --filter ApfelChatTests.SSEParserTests  # specific test class
```

All ViewModels tested with mock services. SQLite tested with :memory: database.
SSE parser tested with fixture data. No UI tests — views are thin.

## Release

```bash
./scripts/release.sh 1.0.0
```
```

- [ ] **Step 7: Create source directory structure with placeholder main.swift**

```bash
mkdir -p Sources/{App,Models,Protocols,Services,ViewModels,Views}
mkdir -p Tests/Mocks
```

Create `Sources/App/ApfelChatApp.swift`:
```swift
import SwiftUI

@main
struct ApfelChatApp: App {
    var body: some Scene {
        WindowGroup {
            Text("apfel-chat")
        }
    }
}
```

- [ ] **Step 8: Verify it builds**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 9: Verify tests run (empty)**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test 2>&1`
Expected: Test suite passes (0 tests)

- [ ] **Step 10: Create GitHub repo and initial commit**

```bash
cd /Users/arthurficial/dev/apfel-chat
gh repo create Arthur-Ficial/apfel-chat --public --description "Super-fast, lightweight, 100% local chat client for on-device AI via apfel" --source . --push
```

Then:
```bash
git add -A
git commit -m "feat: project scaffold — Package.swift, CLAUDE.md, build infrastructure"
git push origin main
```

---

### Task 2: Data Models

**Files:**
- Create: `Sources/Models/Conversation.swift`
- Create: `Sources/Models/Message.swift`
- Create: `Sources/Models/ModelSettings.swift`
- Create: `Sources/Models/ServerHealth.swift`
- Create: `Sources/Models/StreamDelta.swift`
- Create: `Sources/Models/TokenUsage.swift`

- [ ] **Step 1: Write tests for data models**

Create `Tests/ModelTests.swift`:
```swift
import Testing
import Foundation
@testable import apfel_chat

@Suite("Data Models")
struct ModelTests {

    @Test("Conversation roundtrips through JSON")
    func conversationCodable() throws {
        let conv = Conversation(
            id: "test-123",
            title: "Hello World",
            systemPrompt: "You are helpful",
            createdAt: Date(timeIntervalSince1970: 1000),
            updatedAt: Date(timeIntervalSince1970: 2000),
            modelSettings: ModelSettings(temperature: 0.7, maxTokens: 1000, seed: nil, jsonMode: false)
        )
        let data = try JSONEncoder().encode(conv)
        let decoded = try JSONDecoder().decode(Conversation.self, from: data)
        #expect(decoded.id == "test-123")
        #expect(decoded.title == "Hello World")
        #expect(decoded.systemPrompt == "You are helpful")
        #expect(decoded.modelSettings?.temperature == 0.7)
        #expect(decoded.modelSettings?.maxTokens == 1000)
    }

    @Test("Message roundtrips through JSON")
    func messageCodable() throws {
        let msg = Message(
            id: "msg-1",
            conversationId: "conv-1",
            role: .user,
            content: "Hello",
            timestamp: Date(timeIntervalSince1970: 1000),
            tokenCount: 5,
            durationMs: nil,
            isStreaming: false
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        #expect(decoded.id == "msg-1")
        #expect(decoded.role == .user)
        #expect(decoded.content == "Hello")
        #expect(decoded.tokenCount == 5)
    }

    @Test("ModelSettings defaults are nil")
    func modelSettingsDefaults() {
        let settings = ModelSettings()
        #expect(settings.temperature == nil)
        #expect(settings.maxTokens == nil)
        #expect(settings.seed == nil)
        #expect(settings.jsonMode == false)
    }

    @Test("ServerHealth decodes from JSON")
    func serverHealthDecoding() throws {
        let json = """
        {"status":"ok","version":"0.8.1","context_window":4096,"model_available":true,"supported_languages":["en","de"]}
        """
        let data = json.data(using: .utf8)!
        let health = try JSONDecoder().decode(ServerHealth.self, from: data)
        #expect(health.status == "ok")
        #expect(health.version == "0.8.1")
        #expect(health.contextWindow == 4096)
        #expect(health.modelAvailable == true)
        #expect(health.supportedLanguages == ["en", "de"])
    }

    @Test("Role raw values match API")
    func roleRawValues() {
        #expect(Role.user.rawValue == "user")
        #expect(Role.assistant.rawValue == "assistant")
        #expect(Role.system.rawValue == "system")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test 2>&1`
Expected: FAIL — types not found

- [ ] **Step 3: Implement data models**

Create `Sources/Models/Conversation.swift`:
```swift
import Foundation

struct Conversation: Identifiable, Codable, Sendable {
    let id: String
    var title: String
    var systemPrompt: String?
    let createdAt: Date
    var updatedAt: Date
    var modelSettings: ModelSettings?

    init(
        id: String = UUID().uuidString,
        title: String,
        systemPrompt: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        modelSettings: ModelSettings? = nil
    ) {
        self.id = id
        self.title = title
        self.systemPrompt = systemPrompt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.modelSettings = modelSettings
    }
}
```

Create `Sources/Models/Message.swift`:
```swift
import Foundation

enum Role: String, Codable, Sendable {
    case user, assistant, system
}

struct Message: Identifiable, Codable, Sendable {
    let id: String
    let conversationId: String
    let role: Role
    var content: String
    let timestamp: Date
    var tokenCount: Int?
    var durationMs: Int?
    var isStreaming: Bool

    init(
        id: String = UUID().uuidString,
        conversationId: String,
        role: Role,
        content: String,
        timestamp: Date = Date(),
        tokenCount: Int? = nil,
        durationMs: Int? = nil,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.tokenCount = tokenCount
        self.durationMs = durationMs
        self.isStreaming = isStreaming
    }
}
```

Create `Sources/Models/ModelSettings.swift`:
```swift
import Foundation

struct ModelSettings: Codable, Sendable, Equatable {
    var temperature: Double?
    var maxTokens: Int?
    var seed: Int?
    var jsonMode: Bool

    init(temperature: Double? = nil, maxTokens: Int? = nil, seed: Int? = nil, jsonMode: Bool = false) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.seed = seed
        self.jsonMode = jsonMode
    }
}
```

Create `Sources/Models/ServerHealth.swift`:
```swift
import Foundation

struct ServerHealth: Codable, Sendable {
    let status: String
    let version: String?
    let contextWindow: Int?
    let modelAvailable: Bool
    let supportedLanguages: [String]?

    enum CodingKeys: String, CodingKey {
        case status, version
        case contextWindow = "context_window"
        case modelAvailable = "model_available"
        case supportedLanguages = "supported_languages"
    }
}
```

Create `Sources/Models/StreamDelta.swift`:
```swift
struct StreamDelta: Sendable {
    let text: String?
    let finishReason: String?
    let usage: TokenUsage?
}
```

Create `Sources/Models/TokenUsage.swift`:
```swift
struct TokenUsage: Sendable, Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter ModelTests 2>&1`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Models/ Tests/ModelTests.swift
git commit -m "feat: data models — Conversation, Message, ModelSettings, ServerHealth, StreamDelta"
```

---

### Task 3: Service Protocols

**Files:**
- Create: `Sources/Protocols/ChatService.swift`
- Create: `Sources/Protocols/ChatPersistence.swift`
- Create: `Sources/Protocols/SpeechInput.swift`
- Create: `Sources/Protocols/SpeechOutput.swift`

- [ ] **Step 1: Create ChatService protocol**

Create `Sources/Protocols/ChatService.swift`:
```swift
import Foundation

protocol ChatService: Sendable {
    func send(messages: [Message], settings: ModelSettings) -> AsyncThrowingStream<StreamDelta, Error>
    func healthCheck() async throws -> ServerHealth
}
```

- [ ] **Step 2: Create ChatPersistence protocol**

Create `Sources/Protocols/ChatPersistence.swift`:
```swift
import Foundation

protocol ChatPersistence: Sendable {
    func createConversation(title: String) async throws -> Conversation
    func listConversations() async throws -> [Conversation]
    func deleteConversation(id: String) async throws
    func addMessage(_ msg: Message, to conversationId: String) async throws
    func messages(for conversationId: String) async throws -> [Message]
    func updateConversation(_ conv: Conversation) async throws
    func search(query: String) async throws -> [Message]
}
```

- [ ] **Step 3: Create SpeechInput protocol**

Create `Sources/Protocols/SpeechInput.swift`:
```swift
@MainActor
protocol SpeechInput: AnyObject {
    var isListening: Bool { get }
    var transcript: String { get }
    var errorMessage: String? { get }
    func requestPermissions() async -> Bool
    func startListening()
    func stopListening() -> String
}
```

- [ ] **Step 4: Create SpeechOutput protocol**

Create `Sources/Protocols/SpeechOutput.swift`:
```swift
@MainActor
protocol SpeechOutput: AnyObject {
    var isSpeaking: Bool { get }
    func speak(_ text: String, languageCode: String)
    func stop()
}
```

- [ ] **Step 5: Verify build**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 6: Commit**

```bash
git add Sources/Protocols/
git commit -m "feat: service protocols — ChatService, ChatPersistence, SpeechInput, SpeechOutput"
```

---

### Task 4: Mock Services for TDD

**Files:**
- Create: `Tests/Mocks/MockChatService.swift`
- Create: `Tests/Mocks/MockPersistence.swift`
- Create: `Tests/Mocks/MockSpeechInput.swift`
- Create: `Tests/Mocks/MockSpeechOutput.swift`

- [ ] **Step 1: Create MockChatService**

Create `Tests/Mocks/MockChatService.swift`:
```swift
import Foundation
@testable import apfel_chat

final class MockChatService: ChatService, @unchecked Sendable {
    var healthResult: ServerHealth = ServerHealth(
        status: "ok", version: "0.8.1", contextWindow: 4096,
        modelAvailable: true, supportedLanguages: ["en"]
    )
    var streamResponses: [String] = ["Hello", " world"]
    var shouldError: Bool = false
    var sendCallCount = 0
    var lastMessages: [Message] = []
    var lastSettings: ModelSettings?

    func send(messages: [Message], settings: ModelSettings) -> AsyncThrowingStream<StreamDelta, Error> {
        sendCallCount += 1
        lastMessages = messages
        lastSettings = settings
        let responses = streamResponses
        let shouldError = shouldError
        return AsyncThrowingStream { continuation in
            if shouldError {
                continuation.finish(throwing: ChatServiceError.serverError("Mock error"))
                return
            }
            for text in responses {
                continuation.yield(StreamDelta(text: text, finishReason: nil, usage: nil))
            }
            continuation.yield(StreamDelta(
                text: nil,
                finishReason: "stop",
                usage: TokenUsage(promptTokens: 10, completionTokens: 5, totalTokens: 15)
            ))
            continuation.finish()
        }
    }

    func healthCheck() async throws -> ServerHealth {
        if shouldError {
            throw ChatServiceError.connectionFailed("Mock connection failed")
        }
        return healthResult
    }
}

enum ChatServiceError: LocalizedError {
    case connectionFailed(String)
    case serverError(String)
    case streamError(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return msg
        case .serverError(let msg): return msg
        case .streamError(let msg): return msg
        }
    }
}
```

- [ ] **Step 2: Create MockPersistence**

Create `Tests/Mocks/MockPersistence.swift`:
```swift
import Foundation
@testable import apfel_chat

actor MockPersistence: ChatPersistence {
    var conversations: [Conversation] = []
    var messageStore: [String: [Message]] = [:]  // conversationId -> messages

    func createConversation(title: String) async throws -> Conversation {
        let conv = Conversation(title: title)
        conversations.append(conv)
        messageStore[conv.id] = []
        return conv
    }

    func listConversations() async throws -> [Conversation] {
        conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    func deleteConversation(id: String) async throws {
        conversations.removeAll { $0.id == id }
        messageStore.removeValue(forKey: id)
    }

    func addMessage(_ msg: Message, to conversationId: String) async throws {
        messageStore[conversationId, default: []].append(msg)
        if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[idx].updatedAt = Date()
        }
    }

    func messages(for conversationId: String) async throws -> [Message] {
        messageStore[conversationId] ?? []
    }

    func updateConversation(_ conv: Conversation) async throws {
        if let idx = conversations.firstIndex(where: { $0.id == conv.id }) {
            conversations[idx] = conv
        }
    }

    func search(query: String) async throws -> [Message] {
        let lowered = query.lowercased()
        return messageStore.values.flatMap { $0 }.filter {
            $0.content.lowercased().contains(lowered)
        }
    }
}
```

- [ ] **Step 3: Create MockSpeechInput**

Create `Tests/Mocks/MockSpeechInput.swift`:
```swift
import Foundation
@testable import apfel_chat

@MainActor
final class MockSpeechInput: SpeechInput {
    var isListening = false
    var transcript = ""
    var errorMessage: String?
    var permissionGranted = true
    var mockTranscript = "Hello from voice"

    func requestPermissions() async -> Bool {
        permissionGranted
    }

    func startListening() {
        isListening = true
        transcript = mockTranscript
    }

    func stopListening() -> String {
        isListening = false
        return transcript
    }
}
```

- [ ] **Step 4: Create MockSpeechOutput**

Create `Tests/Mocks/MockSpeechOutput.swift`:
```swift
import Foundation
@testable import apfel_chat

@MainActor
final class MockSpeechOutput: SpeechOutput {
    var isSpeaking = false
    var lastSpokenText: String?
    var lastLanguageCode: String?

    func speak(_ text: String, languageCode: String) {
        isSpeaking = true
        lastSpokenText = text
        lastLanguageCode = languageCode
    }

    func stop() {
        isSpeaking = false
    }
}
```

- [ ] **Step 5: Verify build with tests**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test 2>&1`
Expected: Build succeeds, existing tests pass

- [ ] **Step 6: Commit**

```bash
git add Tests/Mocks/
git commit -m "feat: mock services — MockChatService, MockPersistence, MockSpeechInput, MockSpeechOutput"
```

---

### Task 5: SSE Parser + ApfelChatService

**Files:**
- Create: `Sources/Services/SSEParser.swift`
- Create: `Sources/Services/ApfelChatService.swift`
- Create: `Tests/SSEParserTests.swift`
- Create: `Tests/ApfelChatServiceTests.swift`

- [ ] **Step 1: Write SSE parser tests**

Create `Tests/SSEParserTests.swift`:
```swift
import Testing
import Foundation
@testable import apfel_chat

@Suite("SSE Parser")
struct SSEParserTests {

    @Test("Parses content delta from SSE line")
    func parseContentDelta() throws {
        let line = """
        data: {"id":"req-1","choices":[{"delta":{"content":"Hello"},"finish_reason":null}]}
        """
        let delta = SSEParser.parse(line: line)
        #expect(delta?.text == "Hello")
        #expect(delta?.finishReason == nil)
    }

    @Test("Parses finish reason")
    func parseFinishReason() throws {
        let line = """
        data: {"id":"req-1","choices":[{"delta":{"content":""},"finish_reason":"stop"}]}
        """
        let delta = SSEParser.parse(line: line)
        #expect(delta?.finishReason == "stop")
    }

    @Test("Parses usage chunk")
    func parseUsage() throws {
        let line = """
        data: {"usage":{"prompt_tokens":10,"completion_tokens":5,"total_tokens":15}}
        """
        let delta = SSEParser.parse(line: line)
        #expect(delta?.usage?.promptTokens == 10)
        #expect(delta?.usage?.completionTokens == 5)
        #expect(delta?.usage?.totalTokens == 15)
    }

    @Test("Returns nil for DONE signal")
    func parseDone() {
        let delta = SSEParser.parse(line: "data: [DONE]")
        #expect(delta == nil)
    }

    @Test("Returns nil for non-data lines")
    func parseNonData() {
        #expect(SSEParser.parse(line: ": keepalive") == nil)
        #expect(SSEParser.parse(line: "") == nil)
        #expect(SSEParser.parse(line: "event: ping") == nil)
    }

    @Test("Parses error in stream")
    func parseStreamError() {
        let line = """
        data: {"error":{"message":"Context length exceeded","type":"context_length_exceeded"}}
        """
        let delta = SSEParser.parse(line: line)
        #expect(delta == nil)
        let error = SSEParser.parseError(line: line)
        #expect(error?.message == "Context length exceeded")
        #expect(error?.type == "context_length_exceeded")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter SSEParserTests 2>&1`
Expected: FAIL — SSEParser not found

- [ ] **Step 3: Implement SSEParser**

Create `Sources/Services/SSEParser.swift`:
```swift
import Foundation

enum SSEParser {
    struct SSEError: Sendable {
        let message: String
        let type: String?
    }

    private struct ChunkResponse: Decodable {
        let id: String?
        let choices: [Choice]?
        let usage: UsageBlock?

        struct Choice: Decodable {
            let delta: Delta?
            let finish_reason: String?
        }
        struct Delta: Decodable {
            let content: String?
        }
        struct UsageBlock: Decodable {
            let prompt_tokens: Int
            let completion_tokens: Int
            let total_tokens: Int
        }
    }

    private struct ErrorResponse: Decodable {
        let error: ErrorDetail
        struct ErrorDetail: Decodable {
            let message: String
            let type: String?
        }
    }

    static func parse(line: String) -> StreamDelta? {
        guard line.hasPrefix("data: ") else { return nil }
        let payload = String(line.dropFirst(6))
        if payload == "[DONE]" { return nil }
        guard let data = payload.data(using: .utf8) else { return nil }

        // Try error first — if it's an error, return nil (use parseError instead)
        if (try? JSONDecoder().decode(ErrorResponse.self, from: data)) != nil {
            return nil
        }

        guard let chunk = try? JSONDecoder().decode(ChunkResponse.self, from: data) else {
            return nil
        }

        // Usage-only chunk
        if let usage = chunk.usage {
            return StreamDelta(
                text: nil,
                finishReason: nil,
                usage: TokenUsage(
                    promptTokens: usage.prompt_tokens,
                    completionTokens: usage.completion_tokens,
                    totalTokens: usage.total_tokens
                )
            )
        }

        // Content/finish chunk
        if let choice = chunk.choices?.first {
            return StreamDelta(
                text: choice.delta?.content,
                finishReason: choice.finish_reason,
                usage: nil
            )
        }

        return nil
    }

    static func parseError(line: String) -> SSEError? {
        guard line.hasPrefix("data: ") else { return nil }
        let payload = String(line.dropFirst(6))
        guard let data = payload.data(using: .utf8) else { return nil }
        guard let errorResp = try? JSONDecoder().decode(ErrorResponse.self, from: data) else {
            return nil
        }
        return SSEError(message: errorResp.error.message, type: errorResp.error.type)
    }
}
```

- [ ] **Step 4: Run SSE parser tests**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter SSEParserTests 2>&1`
Expected: All 6 tests PASS

- [ ] **Step 5: Write ApfelChatService request-building tests**

Create `Tests/ApfelChatServiceTests.swift`:
```swift
import Testing
import Foundation
@testable import apfel_chat

@Suite("ApfelChatService")
struct ApfelChatServiceTests {

    @Test("Builds correct request body")
    func requestBody() throws {
        let service = ApfelChatService(baseURL: URL(string: "http://127.0.0.1:11440")!)
        let messages = [
            Message(conversationId: "c1", role: .system, content: "Be helpful"),
            Message(conversationId: "c1", role: .user, content: "Hello"),
        ]
        let settings = ModelSettings(temperature: 0.7, maxTokens: 1000)
        let request = service.buildRequest(messages: messages, settings: settings)

        #expect(request.model == "apple-foundationmodel")
        #expect(request.stream == true)
        #expect(request.messages.count == 2)
        #expect(request.messages[0].role == "system")
        #expect(request.messages[0].content == "Be helpful")
        #expect(request.messages[1].role == "user")
        #expect(request.messages[1].content == "Hello")
        #expect(request.temperature == 0.7)
        #expect(request.max_tokens == 1000)
    }

    @Test("Builds request with nil settings")
    func requestNilSettings() throws {
        let service = ApfelChatService(baseURL: URL(string: "http://127.0.0.1:11440")!)
        let messages = [Message(conversationId: "c1", role: .user, content: "Hi")]
        let settings = ModelSettings()
        let request = service.buildRequest(messages: messages, settings: settings)

        #expect(request.temperature == nil)
        #expect(request.max_tokens == nil)
        #expect(request.seed == nil)
        #expect(request.response_format == nil)
    }

    @Test("JSON mode sets response_format")
    func jsonMode() throws {
        let service = ApfelChatService(baseURL: URL(string: "http://127.0.0.1:11440")!)
        let messages = [Message(conversationId: "c1", role: .user, content: "Hi")]
        let settings = ModelSettings(jsonMode: true)
        let request = service.buildRequest(messages: messages, settings: settings)

        #expect(request.response_format?.type == "json_object")
    }

    @Test("User-facing error messages")
    func errorMessages() {
        #expect(ApfelChatService.userFacingError("guardrail triggered").contains("safety"))
        #expect(ApfelChatService.userFacingError("context length exceeded").contains("context"))
        #expect(ApfelChatService.userFacingError("rate limit reached").contains("Rate"))
        #expect(ApfelChatService.userFacingError("some unknown error") == "some unknown error")
    }
}
```

- [ ] **Step 6: Run to verify they fail**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter ApfelChatServiceTests 2>&1`
Expected: FAIL — ApfelChatService not found

- [ ] **Step 7: Implement ApfelChatService**

Create `Sources/Services/ApfelChatService.swift`:
```swift
import Foundation

final class ApfelChatService: ChatService, @unchecked Sendable {
    var baseURL: URL
    var modelName: String

    init(baseURL: URL, modelName: String = "apple-foundationmodel") {
        self.baseURL = baseURL
        self.modelName = modelName
    }

    init(port: Int, modelName: String = "apple-foundationmodel") {
        self.baseURL = URL(string: "http://127.0.0.1:\(port)")!
        self.modelName = modelName
    }

    // MARK: - Request Types

    struct ChatRequest: Encodable {
        let model: String
        let messages: [RequestMessage]
        let stream: Bool
        let temperature: Double?
        let max_tokens: Int?
        let seed: Int?
        let response_format: ResponseFormat?

        struct RequestMessage: Encodable {
            let role: String
            let content: String
        }
        struct ResponseFormat: Encodable {
            let type: String
        }
    }

    // MARK: - Build Request (testable)

    func buildRequest(messages: [Message], settings: ModelSettings) -> ChatRequest {
        let apiMessages = messages.map {
            ChatRequest.RequestMessage(role: $0.role.rawValue, content: $0.content)
        }
        return ChatRequest(
            model: modelName,
            messages: apiMessages,
            stream: true,
            temperature: settings.temperature,
            max_tokens: settings.maxTokens,
            seed: settings.seed,
            response_format: settings.jsonMode ? .init(type: "json_object") : nil
        )
    }

    // MARK: - ChatService Protocol

    func send(messages: [Message], settings: ModelSettings) -> AsyncThrowingStream<StreamDelta, Error> {
        let request = buildRequest(messages: messages, settings: settings)
        let url = URL(string: "/v1/chat/completions", relativeTo: baseURL)!

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, httpResponse) = try await URLSession.shared.bytes(for: urlRequest)

                    if let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode, statusCode >= 400 {
                        var errorData = Data()
                        for try await byte in bytes {
                            errorData.append(byte)
                        }
                        let errorText = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.finish(throwing: ChatServiceError.serverError(
                            Self.userFacingError(errorText)
                        ))
                        return
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: [DONE]") { break }

                        if let error = SSEParser.parseError(line: line) {
                            continuation.finish(throwing: ChatServiceError.streamError(
                                Self.userFacingError(error.message)
                            ))
                            return
                        }

                        if let delta = SSEParser.parse(line: line) {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ChatServiceError.connectionFailed(
                        "Connection failed: \(error.localizedDescription)"
                    ))
                }
            }
        }
    }

    func healthCheck() async throws -> ServerHealth {
        let url = URL(string: "/health", relativeTo: baseURL)!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ChatServiceError.connectionFailed("Server returned non-200 status")
        }
        return try JSONDecoder().decode(ServerHealth.self, from: data)
    }

    // MARK: - Error Helpers

    static func userFacingError(_ raw: String) -> String {
        let lowered = raw.lowercased()
        if lowered.contains("guardrail") || lowered.contains("safety") {
            return "Content blocked by on-device safety filters. Try rephrasing."
        }
        if lowered.contains("context") && lowered.contains("exceed") {
            return "Input exceeds the context window. Shorten your conversation or start a new chat."
        }
        if lowered.contains("rate limit") {
            return "Rate limited. Wait a moment and try again."
        }
        if lowered.contains("concurrent") || lowered.contains("capacity") {
            return "Server at max capacity. Try again in a moment."
        }
        return raw
    }
}
```

- [ ] **Step 8: Run all tests**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test 2>&1`
Expected: All tests PASS (SSEParser + ApfelChatService + Models)

- [ ] **Step 9: Commit**

```bash
git add Sources/Services/SSEParser.swift Sources/Services/ApfelChatService.swift Tests/SSEParserTests.swift Tests/ApfelChatServiceTests.swift
git commit -m "feat: SSE parser + ApfelChatService — streaming HTTP client for apfel"
```

---

### Task 6: SQLite Persistence

**Files:**
- Create: `Sources/Services/SQLitePersistence.swift`
- Create: `Tests/SQLitePersistenceTests.swift`

- [ ] **Step 1: Write persistence tests**

Create `Tests/SQLitePersistenceTests.swift`:
```swift
import Testing
import Foundation
@testable import apfel_chat

@Suite("SQLite Persistence")
struct SQLitePersistenceTests {
    private func makeInMemory() throws -> SQLitePersistence {
        try SQLitePersistence(path: ":memory:")
    }

    @Test("Create and list conversations")
    func createAndList() async throws {
        let db = try makeInMemory()
        let conv1 = try await db.createConversation(title: "First chat")
        let conv2 = try await db.createConversation(title: "Second chat")
        let list = try await db.listConversations()
        #expect(list.count == 2)
        // Most recent first
        #expect(list[0].id == conv2.id)
        #expect(list[1].id == conv1.id)
    }

    @Test("Delete conversation removes it and its messages")
    func deleteConversation() async throws {
        let db = try makeInMemory()
        let conv = try await db.createConversation(title: "To delete")
        let msg = Message(conversationId: conv.id, role: .user, content: "Hello")
        try await db.addMessage(msg, to: conv.id)

        try await db.deleteConversation(id: conv.id)
        let list = try await db.listConversations()
        #expect(list.isEmpty)
        let msgs = try await db.messages(for: conv.id)
        #expect(msgs.isEmpty)
    }

    @Test("Add and retrieve messages in order")
    func addAndRetrieveMessages() async throws {
        let db = try makeInMemory()
        let conv = try await db.createConversation(title: "Chat")
        let msg1 = Message(conversationId: conv.id, role: .user, content: "Hello")
        let msg2 = Message(conversationId: conv.id, role: .assistant, content: "Hi there")
        try await db.addMessage(msg1, to: conv.id)
        try await db.addMessage(msg2, to: conv.id)

        let msgs = try await db.messages(for: conv.id)
        #expect(msgs.count == 2)
        #expect(msgs[0].role == .user)
        #expect(msgs[0].content == "Hello")
        #expect(msgs[1].role == .assistant)
        #expect(msgs[1].content == "Hi there")
    }

    @Test("Update conversation title")
    func updateConversation() async throws {
        let db = try makeInMemory()
        var conv = try await db.createConversation(title: "Old title")
        conv.title = "New title"
        try await db.updateConversation(conv)

        let list = try await db.listConversations()
        #expect(list[0].title == "New title")
    }

    @Test("Search finds messages across conversations")
    func searchMessages() async throws {
        let db = try makeInMemory()
        let conv1 = try await db.createConversation(title: "Chat 1")
        let conv2 = try await db.createConversation(title: "Chat 2")
        try await db.addMessage(
            Message(conversationId: conv1.id, role: .user, content: "Tell me about Swift"),
            to: conv1.id
        )
        try await db.addMessage(
            Message(conversationId: conv2.id, role: .user, content: "Swift is great"),
            to: conv2.id
        )
        try await db.addMessage(
            Message(conversationId: conv2.id, role: .user, content: "Python too"),
            to: conv2.id
        )

        let results = try await db.search(query: "swift")
        #expect(results.count == 2)
    }

    @Test("Update message content")
    func updateMessage() async throws {
        let db = try makeInMemory()
        let conv = try await db.createConversation(title: "Chat")
        let msg = Message(conversationId: conv.id, role: .assistant, content: "Partial")
        try await db.addMessage(msg, to: conv.id)

        var updated = msg
        updated.content = "Full response here"
        updated.tokenCount = 42
        try await db.updateMessage(updated)

        let msgs = try await db.messages(for: conv.id)
        #expect(msgs[0].content == "Full response here")
        #expect(msgs[0].tokenCount == 42)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter SQLitePersistenceTests 2>&1`
Expected: FAIL — SQLitePersistence not found

- [ ] **Step 3: Implement SQLitePersistence**

Create `Sources/Services/SQLitePersistence.swift`:
```swift
import Foundation
#if canImport(SQLite3)
import SQLite3
#endif

final class SQLitePersistence: ChatPersistence, @unchecked Sendable {
    private let db: OpaquePointer

    init(path: String = SQLitePersistence.defaultPath()) throws {
        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &dbPointer, flags, nil) == SQLITE_OK,
              let db = dbPointer else {
            let msg = dbPointer.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown"
            sqlite3_close(dbPointer)
            throw PersistenceError.openFailed(msg)
        }
        self.db = db

        // WAL mode for concurrent reads
        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON", nil, nil, nil)

        try createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    static func defaultPath() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("apfel-chat")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chats.db").path
    }

    // MARK: - Schema

    private func createTables() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS conversations (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            system_prompt TEXT,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            model_settings TEXT
        );
        CREATE TABLE IF NOT EXISTS messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp REAL NOT NULL,
            token_count INTEGER,
            duration_ms INTEGER,
            is_streaming INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, timestamp);
        """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw PersistenceError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Conversations

    func createConversation(title: String) async throws -> Conversation {
        let conv = Conversation(title: title)
        let sql = "INSERT INTO conversations (id, title, system_prompt, created_at, updated_at, model_settings) VALUES (?, ?, ?, ?, ?, ?)"
        try execute(sql, bindings: [
            .text(conv.id), .text(conv.title), .textOrNull(conv.systemPrompt),
            .real(conv.createdAt.timeIntervalSince1970),
            .real(conv.updatedAt.timeIntervalSince1970),
            .textOrNull(conv.modelSettings.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) })
        ])
        return conv
    }

    func listConversations() async throws -> [Conversation] {
        let sql = "SELECT id, title, system_prompt, created_at, updated_at, model_settings FROM conversations ORDER BY updated_at DESC"
        return try query(sql) { stmt in
            let settingsJSON = columnTextOrNil(stmt, 5)
            let settings: ModelSettings? = settingsJSON.flatMap {
                try? JSONDecoder().decode(ModelSettings.self, from: $0.data(using: .utf8)!)
            }
            return Conversation(
                id: String(cString: sqlite3_column_text(stmt, 0)),
                title: String(cString: sqlite3_column_text(stmt, 1)),
                systemPrompt: columnTextOrNil(stmt, 2),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4)),
                modelSettings: settings
            )
        }
    }

    func deleteConversation(id: String) async throws {
        try execute("DELETE FROM messages WHERE conversation_id = ?", bindings: [.text(id)])
        try execute("DELETE FROM conversations WHERE id = ?", bindings: [.text(id)])
    }

    func updateConversation(_ conv: Conversation) async throws {
        let settingsJSON = conv.modelSettings.flatMap {
            try? String(data: JSONEncoder().encode($0), encoding: .utf8)
        }
        try execute(
            "UPDATE conversations SET title = ?, system_prompt = ?, updated_at = ?, model_settings = ? WHERE id = ?",
            bindings: [
                .text(conv.title), .textOrNull(conv.systemPrompt),
                .real(conv.updatedAt.timeIntervalSince1970),
                .textOrNull(settingsJSON), .text(conv.id)
            ]
        )
    }

    // MARK: - Messages

    func addMessage(_ msg: Message, to conversationId: String) async throws {
        let sql = "INSERT INTO messages (id, conversation_id, role, content, timestamp, token_count, duration_ms, is_streaming) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        try execute(sql, bindings: [
            .text(msg.id), .text(conversationId), .text(msg.role.rawValue),
            .text(msg.content), .real(msg.timestamp.timeIntervalSince1970),
            .intOrNull(msg.tokenCount), .intOrNull(msg.durationMs),
            .int(msg.isStreaming ? 1 : 0)
        ])
        // Update conversation's updatedAt
        try execute(
            "UPDATE conversations SET updated_at = ? WHERE id = ?",
            bindings: [.real(Date().timeIntervalSince1970), .text(conversationId)]
        )
    }

    func messages(for conversationId: String) async throws -> [Message] {
        let sql = "SELECT id, conversation_id, role, content, timestamp, token_count, duration_ms, is_streaming FROM messages WHERE conversation_id = ? ORDER BY timestamp ASC"
        return try query(sql, bindings: [.text(conversationId)]) { stmt in
            Message(
                id: String(cString: sqlite3_column_text(stmt, 0)),
                conversationId: String(cString: sqlite3_column_text(stmt, 1)),
                role: Role(rawValue: String(cString: sqlite3_column_text(stmt, 2))) ?? .user,
                content: String(cString: sqlite3_column_text(stmt, 3)),
                timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4)),
                tokenCount: columnIntOrNil(stmt, 5),
                durationMs: columnIntOrNil(stmt, 6),
                isStreaming: sqlite3_column_int(stmt, 7) != 0
            )
        }
    }

    func updateMessage(_ msg: Message) async throws {
        try execute(
            "UPDATE messages SET content = ?, token_count = ?, duration_ms = ?, is_streaming = ? WHERE id = ?",
            bindings: [
                .text(msg.content), .intOrNull(msg.tokenCount),
                .intOrNull(msg.durationMs), .int(msg.isStreaming ? 1 : 0),
                .text(msg.id)
            ]
        )
    }

    func search(query: String) async throws -> [Message] {
        let sql = "SELECT id, conversation_id, role, content, timestamp, token_count, duration_ms, is_streaming FROM messages WHERE content LIKE ? ORDER BY timestamp DESC LIMIT 100"
        return try self.query(sql, bindings: [.text("%\(query)%")]) { stmt in
            Message(
                id: String(cString: sqlite3_column_text(stmt, 0)),
                conversationId: String(cString: sqlite3_column_text(stmt, 1)),
                role: Role(rawValue: String(cString: sqlite3_column_text(stmt, 2))) ?? .user,
                content: String(cString: sqlite3_column_text(stmt, 3)),
                timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4)),
                tokenCount: columnIntOrNil(stmt, 5),
                durationMs: columnIntOrNil(stmt, 6),
                isStreaming: sqlite3_column_int(stmt, 7) != 0
            )
        }
    }

    // MARK: - SQLite Helpers

    private enum Binding {
        case text(String)
        case textOrNull(String?)
        case int(Int)
        case intOrNull(Int?)
        case real(Double)
    }

    private func execute(_ sql: String, bindings: [Binding] = []) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PersistenceError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt: stmt!, bindings: bindings)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw PersistenceError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func query<T>(_ sql: String, bindings: [Binding] = [], map: (OpaquePointer) -> T) throws -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PersistenceError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt: stmt!, bindings: bindings)
        var results: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(map(stmt!))
        }
        return results
    }

    private func bind(stmt: OpaquePointer, bindings: [Binding]) {
        for (i, binding) in bindings.enumerated() {
            let idx = Int32(i + 1)
            switch binding {
            case .text(let v): sqlite3_bind_text(stmt, idx, v, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .textOrNull(let v):
                if let v { sqlite3_bind_text(stmt, idx, v, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
                else { sqlite3_bind_null(stmt, idx) }
            case .int(let v): sqlite3_bind_int(stmt, idx, Int32(v))
            case .intOrNull(let v):
                if let v { sqlite3_bind_int(stmt, idx, Int32(v)) }
                else { sqlite3_bind_null(stmt, idx) }
            case .real(let v): sqlite3_bind_double(stmt, idx, v)
            }
        }
    }

    private func columnTextOrNil(_ stmt: OpaquePointer, _ col: Int32) -> String? {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL else { return nil }
        return String(cString: sqlite3_column_text(stmt, col))
    }

    private func columnIntOrNil(_ stmt: OpaquePointer, _ col: Int32) -> Int? {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int(stmt, col))
    }
}

enum PersistenceError: LocalizedError {
    case openFailed(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let msg): return "Database open failed: \(msg)"
        case .queryFailed(let msg): return "Query failed: \(msg)"
        }
    }
}
```

- [ ] **Step 4: Run persistence tests**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter SQLitePersistenceTests 2>&1`
Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Services/SQLitePersistence.swift Tests/SQLitePersistenceTests.swift
git commit -m "feat: SQLite persistence — conversations + messages with search, raw libsqlite3"
```

---

### Task 7: Server Manager

**Files:**
- Create: `Sources/App/ServerManager.swift`
- Create: `Tests/ServerManagerTests.swift`

- [ ] **Step 1: Write server manager tests**

Create `Tests/ServerManagerTests.swift`:
```swift
import Testing
import Foundation
@testable import apfel_chat

@Suite("Server Manager")
struct ServerManagerTests {

    @Test("findApfelBinary returns path when apfel exists in PATH")
    func findApfelInPath() {
        // apfel should be installed on this machine
        let path = ServerManager.findApfelBinary()
        #expect(path != nil)
    }

    @Test("isPortAvailable returns true for unused port")
    func portAvailable() {
        // Very high port unlikely to be in use
        let available = ServerManager.isPortAvailable(59999)
        #expect(available == true)
    }

    @Test("findAvailablePort returns a port in range")
    func findPort() {
        let port = ServerManager.findAvailablePort(startingAt: 59990)
        #expect(port >= 59990)
        #expect(port < 60000)
    }

    @Test("buildArguments creates correct flags")
    func buildArgs() {
        let args = ServerManager.buildArguments(port: 11440)
        #expect(args.contains("--serve"))
        #expect(args.contains("--port"))
        #expect(args.contains("11440"))
        #expect(args.contains("--cors"))
        // No --debug flag (not a debug tool)
        #expect(!args.contains("--debug"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter ServerManagerTests 2>&1`
Expected: FAIL — ServerManager not found

- [ ] **Step 3: Implement ServerManager**

Create `Sources/App/ServerManager.swift`:
```swift
import Foundation

@MainActor
final class ServerManager {
    enum State {
        case idle
        case starting
        case running(port: Int, process: Process?)
        case failed(String)
    }

    private(set) var state: State = .idle
    private var serverProcess: Process?

    /// Find apfel binary in PATH or known locations.
    static func findApfelBinary() -> String? {
        if let resolved = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":").map({ "\($0)/apfel" })
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return resolved
        }
        let fallbacks = ["/usr/local/bin/apfel", "/opt/homebrew/bin/apfel"]
        return fallbacks.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Check if a port is available by attempting to bind.
    static func isPortAvailable(_ port: Int) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        var optval: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &optval, socklen_t(MemoryLayout<Int32>.size))

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }

    /// Find first available port starting from given port.
    static func findAvailablePort(startingAt: Int = 11440) -> Int {
        for port in startingAt..<(startingAt + 10) {
            if isPortAvailable(port) { return port }
        }
        return startingAt // fallback
    }

    /// Build apfel server arguments.
    static func buildArguments(port: Int) -> [String] {
        ["--serve", "--port", "\(port)", "--cors"]
    }

    /// Try to connect to an already-running apfel server.
    func tryExistingServer() async -> Int? {
        let ports = [11434, 11435] + Array(11440...11449)
        for port in ports {
            let url = URL(string: "http://127.0.0.1:\(port)/health")!
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                if (response as? HTTPURLResponse)?.statusCode == 200 {
                    state = .running(port: port, process: nil)
                    return port
                }
            } catch {
                continue
            }
        }
        return nil
    }

    /// Start apfel server. Returns port on success.
    func start() async -> Int? {
        state = .starting

        // Check for existing server first
        if let port = await tryExistingServer() {
            printToStderr("apfel-chat: connected to existing server on port \(port)")
            return port
        }

        // Find apfel binary
        guard let apfelPath = Self.findApfelBinary() else {
            state = .failed("apfel not found. Install: brew install Arthur-Ficial/tap/apfel")
            printToStderr("apfel-chat: error: apfel not found in PATH")
            return nil
        }

        let port = Self.findAvailablePort()
        let args = Self.buildArguments(port: port)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: apfelPath)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            self.serverProcess = process
            printToStderr("apfel-chat: server starting on port \(port) (PID: \(process.processIdentifier))")
        } catch {
            state = .failed("Failed to start apfel: \(error.localizedDescription)")
            return nil
        }

        // Wait for server readiness
        let ready = await waitForReady(port: port, timeout: 8.0)
        if ready {
            state = .running(port: port, process: process)
            printToStderr("apfel-chat: server ready on port \(port)")
            return port
        } else {
            process.terminate()
            state = .failed("Server failed to start within 8 seconds")
            printToStderr("apfel-chat: server failed to start")
            return nil
        }
    }

    func stop() {
        if let process = serverProcess, process.isRunning {
            process.terminate()
            printToStderr("apfel-chat: server terminated")
        }
        serverProcess = nil
        state = .idle
    }

    private func waitForReady(port: Int, timeout: Double) async -> Bool {
        let start = Date()
        let url = URL(string: "http://127.0.0.1:\(port)/health")!
        while Date().timeIntervalSince(start) < timeout {
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                if (response as? HTTPURLResponse)?.statusCode == 200 { return true }
            } catch {}
            try? await Task.sleep(for: .milliseconds(200))
        }
        return false
    }
}

func printToStderr(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}
```

- [ ] **Step 4: Run server manager tests**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter ServerManagerTests 2>&1`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/App/ServerManager.swift Tests/ServerManagerTests.swift
git commit -m "feat: ServerManager — find apfel, port selection, server lifecycle"
```

---

### Task 8: SettingsViewModel

**Files:**
- Create: `Sources/ViewModels/SettingsViewModel.swift`
- Create: `Tests/SettingsViewModelTests.swift`

- [ ] **Step 1: Write settings tests**

Create `Tests/SettingsViewModelTests.swift`:
```swift
import Testing
import Foundation
@testable import apfel_chat

@Suite("SettingsViewModel")
@MainActor
struct SettingsViewModelTests {

    @Test("Default values")
    func defaults() {
        let vm = SettingsViewModel()
        #expect(vm.temperature == nil)
        #expect(vm.maxTokens == nil)
        #expect(vm.seed == nil)
        #expect(vm.jsonMode == false)
        #expect(vm.baseURL == "http://127.0.0.1:11440")
        #expect(vm.modelName == "apple-foundationmodel")
        #expect(vm.ttsLanguage == "en-US")
        #expect(vm.autoSpeak == false)
    }

    @Test("toModelSettings converts correctly")
    func toModelSettings() {
        let vm = SettingsViewModel()
        vm.temperature = 0.7
        vm.maxTokens = 1000
        vm.jsonMode = true
        let settings = vm.toModelSettings()
        #expect(settings.temperature == 0.7)
        #expect(settings.maxTokens == 1000)
        #expect(settings.jsonMode == true)
    }

    @Test("Saves and restores from UserDefaults")
    func persistence() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let vm1 = SettingsViewModel(defaults: defaults)
        vm1.temperature = 0.5
        vm1.ttsLanguage = "de-DE"
        vm1.autoSpeak = true
        vm1.save()

        let vm2 = SettingsViewModel(defaults: defaults)
        vm2.load()
        #expect(vm2.temperature == 0.5)
        #expect(vm2.ttsLanguage == "de-DE")
        #expect(vm2.autoSpeak == true)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter SettingsViewModelTests 2>&1`
Expected: FAIL — SettingsViewModel not found

- [ ] **Step 3: Implement SettingsViewModel**

Create `Sources/ViewModels/SettingsViewModel.swift`:
```swift
import Foundation
import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {
    var temperature: Double?
    var maxTokens: Int?
    var seed: Int?
    var jsonMode: Bool = false

    var baseURL: String = "http://127.0.0.1:11440"
    var modelName: String = "apple-foundationmodel"

    var ttsLanguage: String = "en-US"
    var autoSpeak: Bool = false

    var showSettings: Bool = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func toModelSettings() -> ModelSettings {
        ModelSettings(
            temperature: temperature,
            maxTokens: maxTokens,
            seed: seed,
            jsonMode: jsonMode
        )
    }

    func save() {
        if let t = temperature { defaults.set(t, forKey: "temperature") }
        else { defaults.removeObject(forKey: "temperature") }
        if let m = maxTokens { defaults.set(m, forKey: "maxTokens") }
        else { defaults.removeObject(forKey: "maxTokens") }
        if let s = seed { defaults.set(s, forKey: "seed") }
        else { defaults.removeObject(forKey: "seed") }
        defaults.set(jsonMode, forKey: "jsonMode")
        defaults.set(baseURL, forKey: "baseURL")
        defaults.set(modelName, forKey: "modelName")
        defaults.set(ttsLanguage, forKey: "ttsLanguage")
        defaults.set(autoSpeak, forKey: "autoSpeak")
    }

    func load() {
        if defaults.object(forKey: "temperature") != nil {
            temperature = defaults.double(forKey: "temperature")
        }
        if defaults.object(forKey: "maxTokens") != nil {
            maxTokens = defaults.integer(forKey: "maxTokens")
        }
        if defaults.object(forKey: "seed") != nil {
            seed = defaults.integer(forKey: "seed")
        }
        jsonMode = defaults.bool(forKey: "jsonMode")
        if let url = defaults.string(forKey: "baseURL"), !url.isEmpty { baseURL = url }
        if let model = defaults.string(forKey: "modelName"), !model.isEmpty { modelName = model }
        if let lang = defaults.string(forKey: "ttsLanguage"), !lang.isEmpty { ttsLanguage = lang }
        autoSpeak = defaults.bool(forKey: "autoSpeak")
    }
}
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter SettingsViewModelTests 2>&1`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ViewModels/SettingsViewModel.swift Tests/SettingsViewModelTests.swift
git commit -m "feat: SettingsViewModel — temperature, tokens, speech, connection with UserDefaults persistence"
```

---

### Task 9: ConversationListViewModel

**Files:**
- Create: `Sources/ViewModels/ConversationListViewModel.swift`
- Create: `Tests/ConversationListViewModelTests.swift`

- [ ] **Step 1: Write conversation list tests**

Create `Tests/ConversationListViewModelTests.swift`:
```swift
import Testing
import Foundation
@testable import apfel_chat

@Suite("ConversationListViewModel")
@MainActor
struct ConversationListViewModelTests {

    private func makeVM() async throws -> (ConversationListViewModel, MockPersistence) {
        let persistence = MockPersistence()
        let vm = ConversationListViewModel(persistence: persistence)
        return (vm, persistence)
    }

    @Test("Create new conversation")
    func createConversation() async throws {
        let (vm, _) = try await makeVM()
        await vm.createConversation()
        #expect(vm.conversations.count == 1)
        #expect(vm.conversations[0].title == "New Chat")
        #expect(vm.selectedId == vm.conversations[0].id)
    }

    @Test("Delete conversation")
    func deleteConversation() async throws {
        let (vm, _) = try await makeVM()
        await vm.createConversation()
        let id = vm.conversations[0].id
        await vm.deleteConversation(id: id)
        #expect(vm.conversations.isEmpty)
        #expect(vm.selectedId == nil)
    }

    @Test("Rename conversation")
    func renameConversation() async throws {
        let (vm, _) = try await makeVM()
        await vm.createConversation()
        let id = vm.conversations[0].id
        await vm.renameConversation(id: id, title: "My Chat")
        #expect(vm.conversations[0].title == "My Chat")
    }

    @Test("Load conversations on refresh")
    func loadConversations() async throws {
        let persistence = MockPersistence()
        _ = try await persistence.createConversation(title: "Existing")
        let vm = ConversationListViewModel(persistence: persistence)
        await vm.loadConversations()
        #expect(vm.conversations.count == 1)
        #expect(vm.conversations[0].title == "Existing")
    }

    @Test("Search filters results")
    func searchConversations() async throws {
        let (vm, persistence) = try await makeVM()
        let conv = try await persistence.createConversation(title: "Chat")
        try await persistence.addMessage(
            Message(conversationId: conv.id, role: .user, content: "Tell me about Swift"),
            to: conv.id
        )
        await vm.loadConversations()
        await vm.search(query: "Swift")
        #expect(vm.searchResults.count == 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter ConversationListViewModelTests 2>&1`
Expected: FAIL

- [ ] **Step 3: Implement ConversationListViewModel**

Create `Sources/ViewModels/ConversationListViewModel.swift`:
```swift
import Foundation
import SwiftUI

@Observable
@MainActor
final class ConversationListViewModel {
    var conversations: [Conversation] = []
    var selectedId: String?
    var searchQuery: String = ""
    var searchResults: [Message] = []
    var errorMessage: String?

    private let persistence: ChatPersistence

    init(persistence: ChatPersistence) {
        self.persistence = persistence
    }

    func loadConversations() async {
        do {
            conversations = try await persistence.listConversations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createConversation() async {
        do {
            let conv = try await persistence.createConversation(title: "New Chat")
            conversations.insert(conv, at: 0)
            selectedId = conv.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteConversation(id: String) async {
        do {
            try await persistence.deleteConversation(id: id)
            conversations.removeAll { $0.id == id }
            if selectedId == id {
                selectedId = conversations.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameConversation(id: String, title: String) async {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[idx].title = title
        do {
            try await persistence.updateConversation(conversations[idx])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        do {
            searchResults = try await persistence.search(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter ConversationListViewModelTests 2>&1`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ViewModels/ConversationListViewModel.swift Tests/ConversationListViewModelTests.swift
git commit -m "feat: ConversationListViewModel — CRUD, search, selection"
```

---

### Task 10: ChatViewModel

**Files:**
- Create: `Sources/ViewModels/ChatViewModel.swift`
- Create: `Tests/ChatViewModelTests.swift`

- [ ] **Step 1: Write chat view model tests**

Create `Tests/ChatViewModelTests.swift`:
```swift
import Testing
import Foundation
@testable import apfel_chat

@Suite("ChatViewModel")
@MainActor
struct ChatViewModelTests {

    private func makeVM() -> (ChatViewModel, MockChatService, MockPersistence) {
        let chatService = MockChatService()
        let persistence = MockPersistence()
        let sttInput = MockSpeechInput()
        let ttsOutput = MockSpeechOutput()
        let vm = ChatViewModel(
            chatService: chatService,
            persistence: persistence,
            speechInput: sttInput,
            speechOutput: ttsOutput
        )
        vm.conversationId = "test-conv"
        return (vm, chatService, persistence)
    }

    @Test("Send message appends user and streams assistant response")
    func sendMessage() async throws {
        let (vm, chatService, _) = makeVM()
        chatService.streamResponses = ["Hello", " world"]
        vm.currentInput = "Hi there"
        await vm.send()

        #expect(vm.messages.count == 2)
        #expect(vm.messages[0].role == .user)
        #expect(vm.messages[0].content == "Hi there")
        #expect(vm.messages[1].role == .assistant)
        #expect(vm.messages[1].content == "Hello world")
        #expect(vm.currentInput == "")
        #expect(vm.isStreaming == false)
    }

    @Test("Send with empty input does nothing")
    func sendEmpty() async throws {
        let (vm, chatService, _) = makeVM()
        vm.currentInput = ""
        await vm.send()
        #expect(vm.messages.isEmpty)
        #expect(chatService.sendCallCount == 0)
    }

    @Test("Error during streaming shows error")
    func streamingError() async throws {
        let (vm, chatService, _) = makeVM()
        chatService.shouldError = true
        vm.currentInput = "Hello"
        await vm.send()

        #expect(vm.messages.count == 1) // just user message
        #expect(vm.errorMessage != nil)
    }

    @Test("Clear removes all messages")
    func clearMessages() async throws {
        let (vm, _, _) = makeVM()
        vm.currentInput = "Test"
        await vm.send()
        vm.clear()
        #expect(vm.messages.isEmpty)
    }

    @Test("Load messages from persistence")
    func loadMessages() async throws {
        let (vm, _, persistence) = makeVM()
        let conv = try await persistence.createConversation(title: "Test")
        vm.conversationId = conv.id
        try await persistence.addMessage(
            Message(conversationId: conv.id, role: .user, content: "Saved msg"),
            to: conv.id
        )
        await vm.loadMessages()
        #expect(vm.messages.count == 1)
        #expect(vm.messages[0].content == "Saved msg")
    }

    @Test("Settings passed to chat service")
    func settingsPassthrough() async throws {
        let (vm, chatService, _) = makeVM()
        vm.settings = ModelSettings(temperature: 0.5, maxTokens: 500)
        vm.currentInput = "Hello"
        await vm.send()
        #expect(chatService.lastSettings?.temperature == 0.5)
        #expect(chatService.lastSettings?.maxTokens == 500)
    }

    @Test("Auto-title from first user message")
    func autoTitle() async throws {
        let (vm, _, persistence) = makeVM()
        let conv = try await persistence.createConversation(title: "New Chat")
        vm.conversationId = conv.id
        vm.currentInput = "What is the meaning of life and why does it matter so much?"
        await vm.send()
        // Title should be truncated first few words
        let conversations = try await persistence.listConversations()
        let updated = conversations.first { $0.id == conv.id }
        #expect(updated?.title != "New Chat")  // should have been auto-titled
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter ChatViewModelTests 2>&1`
Expected: FAIL

- [ ] **Step 3: Implement ChatViewModel**

Create `Sources/ViewModels/ChatViewModel.swift`:
```swift
import Foundation
import SwiftUI

@Observable
@MainActor
final class ChatViewModel {
    var messages: [Message] = []
    var currentInput: String = ""
    var isStreaming: Bool = false
    var errorMessage: String?
    var conversationId: String?
    var systemPrompt: String?
    var settings: ModelSettings = ModelSettings()

    private let chatService: ChatService
    private let persistence: ChatPersistence
    let speechInput: (any SpeechInput)?
    let speechOutput: (any SpeechOutput)?

    private var streamTask: Task<Void, Never>?

    init(
        chatService: ChatService,
        persistence: ChatPersistence,
        speechInput: (any SpeechInput)? = nil,
        speechOutput: (any SpeechOutput)? = nil
    ) {
        self.chatService = chatService
        self.persistence = persistence
        self.speechInput = speechInput
        self.speechOutput = speechOutput
    }

    func send() async {
        let text = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let convId = conversationId else { return }

        currentInput = ""
        errorMessage = nil

        // Add user message
        let userMsg = Message(conversationId: convId, role: .user, content: text)
        messages.append(userMsg)
        try? await persistence.addMessage(userMsg, to: convId)

        // Auto-title on first user message
        if messages.count == 1 {
            await autoTitle(from: text, conversationId: convId)
        }

        // Build message history for API (include system prompt)
        var apiMessages: [Message] = []
        if let sys = systemPrompt, !sys.isEmpty {
            apiMessages.append(Message(conversationId: convId, role: .system, content: sys))
        }
        apiMessages.append(contentsOf: messages)

        // Stream response
        isStreaming = true
        var assistantMsg = Message(conversationId: convId, role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMsg)
        let assistantIdx = messages.count - 1

        let start = Date()
        let stream = chatService.send(messages: apiMessages, settings: settings)

        do {
            for try await delta in stream {
                if let text = delta.text {
                    messages[assistantIdx].content += text
                }
                if let usage = delta.usage {
                    messages[assistantIdx].tokenCount = usage.totalTokens
                }
            }
            messages[assistantIdx].isStreaming = false
            messages[assistantIdx].durationMs = Int(Date().timeIntervalSince(start) * 1000)
            assistantMsg = messages[assistantIdx]
            try? await persistence.addMessage(assistantMsg, to: convId)
        } catch {
            // Remove empty assistant message on error
            if messages[assistantIdx].content.isEmpty {
                messages.remove(at: assistantIdx)
            } else {
                messages[assistantIdx].isStreaming = false
            }
            errorMessage = error.localizedDescription
        }

        isStreaming = false
    }

    func loadMessages() async {
        guard let convId = conversationId else { return }
        do {
            messages = try await persistence.messages(for: convId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        messages = []
        errorMessage = nil
    }

    func stopStreaming() {
        streamTask?.cancel()
        isStreaming = false
    }

    // MARK: - Speech

    func toggleListening() async {
        guard let stt = speechInput else { return }
        if stt.isListening {
            let transcript = stt.stopListening()
            if !transcript.isEmpty {
                currentInput = transcript
                await send()
            }
        } else {
            let granted = await stt.requestPermissions()
            if granted {
                stt.startListening()
            }
        }
    }

    func speakLastResponse() {
        guard let tts = speechOutput else { return }
        guard let lastAssistant = messages.last(where: { $0.role == .assistant }) else { return }
        tts.speak(lastAssistant.content, languageCode: "en-US")
    }

    // MARK: - Private

    private func autoTitle(from text: String, conversationId: String) async {
        let words = text.split(separator: " ").prefix(6).joined(separator: " ")
        let title = words.count > 40 ? String(words.prefix(40)) + "..." : words
        guard !title.isEmpty else { return }

        do {
            let conversations = try await persistence.listConversations()
            if var conv = conversations.first(where: { $0.id == conversationId }) {
                conv.title = title
                try await persistence.updateConversation(conv)
            }
        } catch {}
    }
}
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter ChatViewModelTests 2>&1`
Expected: All 7 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ViewModels/ChatViewModel.swift Tests/ChatViewModelTests.swift
git commit -m "feat: ChatViewModel — send, stream, persist, speech integration, auto-title"
```

---

### Task 11: Markdown Renderer

**Files:**
- Create: `Sources/Views/MarkdownRenderer.swift`
- Create: `Tests/MarkdownRendererTests.swift`

- [ ] **Step 1: Write markdown renderer tests**

Create `Tests/MarkdownRendererTests.swift`:
```swift
import Testing
import Foundation
@testable import apfel_chat

@Suite("MarkdownRenderer")
struct MarkdownRendererTests {

    @Test("Renders plain text")
    func plainText() throws {
        let result = MarkdownRenderer.render("Hello world")
        #expect(!result.characters.isEmpty)
    }

    @Test("Detects code blocks")
    func codeBlocks() {
        let md = """
        Here is some code:
        ```swift
        let x = 42
        ```
        """
        let blocks = MarkdownRenderer.parseBlocks(md)
        #expect(blocks.count == 2)
        #expect(blocks[0].type == .text)
        #expect(blocks[1].type == .code)
        #expect(blocks[1].language == "swift")
        #expect(blocks[1].content.contains("let x = 42"))
    }

    @Test("Detects JSON and pretty-prints")
    func jsonDetection() {
        let json = """
        {"name":"test","value":42}
        """
        #expect(MarkdownRenderer.isJSON(json) == true)
        let pretty = MarkdownRenderer.prettyJSON(json)
        #expect(pretty.contains("\"name\""))
        #expect(pretty.contains("\n"))  // formatted with newlines
    }

    @Test("Non-JSON returns false")
    func notJSON() {
        #expect(MarkdownRenderer.isJSON("Hello world") == false)
        #expect(MarkdownRenderer.isJSON("") == false)
    }

    @Test("Parses mixed content blocks")
    func mixedBlocks() {
        let md = """
        # Title
        Some text here.

        ```python
        print("hello")
        ```

        More text.
        """
        let blocks = MarkdownRenderer.parseBlocks(md)
        #expect(blocks.count == 3)
        #expect(blocks[0].type == .text)
        #expect(blocks[1].type == .code)
        #expect(blocks[1].language == "python")
        #expect(blocks[2].type == .text)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter MarkdownRendererTests 2>&1`
Expected: FAIL

- [ ] **Step 3: Implement MarkdownRenderer**

Create `Sources/Views/MarkdownRenderer.swift`:
```swift
import Foundation
import SwiftUI

enum MarkdownRenderer {
    struct ContentBlock: Identifiable {
        let id = UUID()
        let type: BlockType
        let content: String
        let language: String?

        enum BlockType { case text, code }
    }

    /// Parse markdown into blocks of text and code.
    static func parseBlocks(_ markdown: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        var currentText = ""
        var inCodeBlock = false
        var codeContent = ""
        var codeLanguage: String?

        for line in markdown.components(separatedBy: "\n") {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    blocks.append(ContentBlock(type: .code, content: codeContent.trimmingCharacters(in: .newlines), language: codeLanguage))
                    codeContent = ""
                    codeLanguage = nil
                    inCodeBlock = false
                } else {
                    // Start code block — flush text
                    let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        blocks.append(ContentBlock(type: .text, content: trimmed, language: nil))
                    }
                    currentText = ""
                    let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeLanguage = lang.isEmpty ? nil : lang
                    inCodeBlock = true
                }
            } else if inCodeBlock {
                if !codeContent.isEmpty { codeContent += "\n" }
                codeContent += line
            } else {
                if !currentText.isEmpty { currentText += "\n" }
                currentText += line
            }
        }

        // Flush remaining
        if inCodeBlock && !codeContent.isEmpty {
            blocks.append(ContentBlock(type: .code, content: codeContent, language: codeLanguage))
        }
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            blocks.append(ContentBlock(type: .text, content: trimmed, language: nil))
        }

        return blocks
    }

    /// Render markdown text to AttributedString.
    static func render(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(markdown)
    }

    /// Check if a string looks like JSON.
    static func isJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else { return false }
        guard let data = trimmed.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    /// Pretty-print JSON.
    static func prettyJSON(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return text }
        return str
    }
}
```

- [ ] **Step 4: Run tests**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test --filter MarkdownRendererTests 2>&1`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Views/MarkdownRenderer.swift Tests/MarkdownRendererTests.swift
git commit -m "feat: MarkdownRenderer — code block parsing, JSON detection, AttributedString rendering"
```

---

### Task 12: Speech Services (STT + TTS)

**Files:**
- Create: `Sources/Services/OnDeviceSpeechInput.swift`
- Create: `Sources/Services/OnDeviceSpeechOutput.swift`

These use real system frameworks (SFSpeechRecognizer, AVSpeechSynthesizer) and cannot be unit-tested without hardware. The protocols + mocks from Task 4 cover testing. Here we implement the real services.

- [ ] **Step 1: Implement OnDeviceSpeechInput (STT)**

Create `Sources/Services/OnDeviceSpeechInput.swift`:
```swift
import Speech
import AVFoundation

@Observable
@MainActor
final class OnDeviceSpeechInput: SpeechInput {
    var isListening = false
    var transcript = ""
    var errorMessage: String?

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var userStoppedSession = false

    init(locale: Locale = Locale(identifier: "en-US")) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    func requestPermissions() async -> Bool {
        // Microphone
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch micStatus {
        case .authorized: break
        case .notDetermined:
            let granted = await withUnsafeContinuation { (c: UnsafeContinuation<Bool, Never>) in
                let handler: @Sendable (Bool) -> Void = { granted in c.resume(returning: granted) }
                AVCaptureDevice.requestAccess(for: .audio, completionHandler: handler)
            }
            if !granted {
                errorMessage = "Microphone access needed. Enable in System Settings > Privacy & Security > Microphone."
                return false
            }
        default:
            errorMessage = "Microphone access needed. Enable in System Settings > Privacy & Security > Microphone."
            return false
        }

        // Speech recognition
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .authorized { return true }
        if speechStatus != .notDetermined {
            errorMessage = "Speech recognition needed. Enable in System Settings > Privacy & Security > Speech Recognition."
            return false
        }

        let authorized = await withUnsafeContinuation { (c: UnsafeContinuation<Bool, Never>) in
            let handler: @Sendable (SFSpeechRecognizerAuthorizationStatus) -> Void = { status in
                c.resume(returning: status == .authorized)
            }
            SFSpeechRecognizer.requestAuthorization(handler)
        }
        if !authorized {
            errorMessage = "Speech recognition not authorized."
        }
        return authorized
    }

    func startListening() {
        guard !isListening, let recognizer, recognizer.isAvailable else { return }
        transcript = ""
        errorMessage = nil
        userStoppedSession = false

        do {
            let engine = AVAudioEngine()
            self.audioEngine = engine

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.recognitionRequest = request

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }
                    if error != nil {
                        if !self.userStoppedSession && self.transcript.isEmpty {
                            self.errorMessage = "Speech recognition failed"
                        }
                        self.cleanup()
                    }
                }
            }

            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                errorMessage = "No microphone input available"
                return
            }

            nonisolated(unsafe) let audioRequest = request
            let tapHandler: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { buffer, _ in
                audioRequest.append(buffer)
            }
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: tapHandler)
            engine.prepare()
            try engine.start()
            isListening = true
        } catch {
            errorMessage = "Failed to start: \(error.localizedDescription)"
            cleanup()
        }
    }

    func stopListening() -> String {
        userStoppedSession = true
        cleanup()
        return transcript
    }

    private func cleanup() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }
}
```

- [ ] **Step 2: Implement OnDeviceSpeechOutput (TTS)**

Create `Sources/Services/OnDeviceSpeechOutput.swift`:
```swift
import AVFoundation

@MainActor
final class OnDeviceSpeechOutput: NSObject, SpeechOutput, AVSpeechSynthesizerDelegate, Observable {
    private let synthesizer = AVSpeechSynthesizer()
    var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, languageCode: String = "en-US") {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestVoice(for: languageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    private func bestVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == languageCode }
        let ranked = voices.sorted { lhs, rhs in
            let lhsSiri = lhs.identifier.lowercased().contains("siri")
            let rhsSiri = rhs.identifier.lowercased().contains("siri")
            if lhsSiri != rhsSiri { return lhsSiri }
            if lhs.quality.rawValue != rhs.quality.rawValue { return lhs.quality.rawValue > rhs.quality.rawValue }
            return lhs.name < rhs.name
        }
        return ranked.first ?? AVSpeechSynthesisVoice(language: languageCode)
    }
}
```

- [ ] **Step 3: Verify build**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add Sources/Services/OnDeviceSpeechInput.swift Sources/Services/OnDeviceSpeechOutput.swift
git commit -m "feat: on-device speech — STT via SFSpeechRecognizer, TTS via AVSpeechSynthesizer"
```

---

### Task 13: SwiftUI Views

**Files:**
- Create: `Sources/Views/ConversationListView.swift`
- Create: `Sources/Views/ChatView.swift`
- Create: `Sources/Views/MessageBubble.swift`
- Create: `Sources/Views/InputBar.swift`
- Create: `Sources/Views/SettingsPanel.swift`

- [ ] **Step 1: Create MessageBubble**

Create `Sources/Views/MessageBubble.swift`:
```swift
import SwiftUI

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                contentView
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let tokens = message.tokenCount {
                    Text("\(tokens) tokens")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        let blocks = MarkdownRenderer.parseBlocks(message.content)
        if blocks.count == 1 && blocks[0].type == .text {
            // Simple text — use AttributedString
            Text(MarkdownRenderer.render(message.content))
                .textSelection(.enabled)
        } else {
            // Mixed content
            VStack(alignment: .leading, spacing: 8) {
                ForEach(blocks) { block in
                    switch block.type {
                    case .text:
                        Text(MarkdownRenderer.render(block.content))
                            .textSelection(.enabled)
                    case .code:
                        VStack(alignment: .leading, spacing: 4) {
                            if let lang = block.language {
                                Text(lang)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(block.content)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(8)
                            }
                            .background(Color(white: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
        }
    }

    private var bubbleBackground: Color {
        switch message.role {
        case .user: return Color.blue.opacity(0.1)
        case .assistant: return Color(white: 0.97)
        case .system: return Color.orange.opacity(0.1)
        }
    }
}
```

- [ ] **Step 2: Create InputBar**

Create `Sources/Views/InputBar.swift`:
```swift
import SwiftUI

struct InputBar: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Mic button
            if viewModel.speechInput != nil {
                Button(action: {
                    Task { await viewModel.toggleListening() }
                }) {
                    Image(systemName: viewModel.speechInput?.isListening == true ? "mic.fill" : "mic")
                        .foregroundStyle(viewModel.speechInput?.isListening == true ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .help("Voice input")
            }

            // Text field
            TextField("Message...", text: $viewModel.currentInput, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .onSubmit {
                    Task { await viewModel.send() }
                }

            // Speaker toggle
            if viewModel.speechOutput != nil {
                Button(action: {
                    if viewModel.speechOutput?.isSpeaking == true {
                        viewModel.speechOutput?.stop()
                    } else {
                        viewModel.speakLastResponse()
                    }
                }) {
                    Image(systemName: viewModel.speechOutput?.isSpeaking == true ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .foregroundStyle(viewModel.speechOutput?.isSpeaking == true ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .help("Read aloud")
            }

            // Send button
            Button(action: {
                Task { await viewModel.send() }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
        }
        .padding(12)
        .background(.white)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color(white: 0.9)), alignment: .top)
    }
}
```

- [ ] **Step 3: Create ChatView**

Create `Sources/Views/ChatView.swift`:
```swift
import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.messages.isEmpty {
                emptyState
            } else {
                messageList
            }

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            InputBar(viewModel: viewModel)
        }
        .background(.white)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("Start a conversation")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Private AI on your Mac")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }

                    if viewModel.isStreaming {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(.leading, 16)
                            Spacer()
                        }
                        .id("streaming-indicator")
                    }
                }
                .padding(16)
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(viewModel.messages.last?.id ?? "streaming-indicator", anchor: .bottom)
                }
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Dismiss") { viewModel.errorMessage = nil }
                .font(.caption)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
    }
}
```

- [ ] **Step 4: Create ConversationListView**

Create `Sources/Views/ConversationListView.swift`:
```swift
import SwiftUI

struct ConversationListView: View {
    @Bindable var viewModel: ConversationListViewModel
    var onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search
            TextField("Search...", text: $viewModel.searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(8)
                .onChange(of: viewModel.searchQuery) {
                    Task { await viewModel.search(query: viewModel.searchQuery) }
                }

            // Conversation list
            List(selection: $viewModel.selectedId) {
                ForEach(viewModel.conversations) { conv in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conv.title)
                            .font(.body)
                            .lineLimit(1)
                        Text(conv.updatedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .tag(conv.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            Task { await viewModel.deleteConversation(id: conv.id) }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: viewModel.selectedId) { _, newId in
                if let id = newId { onSelect(id) }
            }
        }
        .frame(minWidth: 200)
        .background(Color(white: 0.96))
    }
}
```

- [ ] **Step 5: Create SettingsPanel**

Create `Sources/Views/SettingsPanel.swift`:
```swift
import SwiftUI

struct SettingsPanel: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var showAdvanced = false

    var body: some View {
        Form {
            Section("General") {
                optionalSlider(label: "Temperature", value: temperatureBinding, range: 0...2, step: 0.1)
                optionalIntField(label: "Max Tokens", value: $viewModel.maxTokens)
                Toggle("JSON Mode", isOn: $viewModel.jsonMode)
            }

            Section("Speech") {
                Picker("Language", selection: $viewModel.ttsLanguage) {
                    Text("English (US)").tag("en-US")
                    Text("English (UK)").tag("en-GB")
                    Text("German").tag("de-DE")
                    Text("French").tag("fr-FR")
                    Text("Spanish").tag("es-ES")
                    Text("Italian").tag("it-IT")
                    Text("Portuguese (BR)").tag("pt-BR")
                    Text("Japanese").tag("ja-JP")
                }
                Toggle("Auto-speak responses", isOn: $viewModel.autoSpeak)
            }

            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                TextField("Server URL", text: $viewModel.baseURL)
                    .textFieldStyle(.roundedBorder)
                TextField("Model Name", text: $viewModel.modelName)
                    .textFieldStyle(.roundedBorder)
                optionalIntField(label: "Seed", value: $viewModel.seed)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 450)
        .onDisappear { viewModel.save() }
    }

    private var temperatureBinding: Binding<Double> {
        Binding(
            get: { viewModel.temperature ?? 0.7 },
            set: { viewModel.temperature = $0 }
        )
    }

    private func optionalSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.1f", value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func optionalIntField(label: String, value: Binding<Int?>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("default", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
        }
    }
}
```

- [ ] **Step 6: Verify build**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 7: Commit**

```bash
git add Sources/Views/
git commit -m "feat: SwiftUI views — ChatView, ConversationList, MessageBubble, InputBar, SettingsPanel"
```

---

### Task 14: App Entry Point + Window Assembly

**Files:**
- Modify: `Sources/App/ApfelChatApp.swift`

- [ ] **Step 1: Implement full ApfelChatApp**

Replace `Sources/App/ApfelChatApp.swift` with:
```swift
import SwiftUI

@main
struct ApfelChatApp: App {
    @State private var serverManager = ServerManager()
    @State private var chatService: ApfelChatService?
    @State private var persistence: SQLitePersistence?
    @State private var conversationListVM: ConversationListViewModel?
    @State private var chatVM: ChatViewModel?
    @State private var settingsVM = SettingsViewModel()
    @State private var serverError: String?
    @State private var isReady = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isReady, let listVM = conversationListVM, let chatVM = chatVM {
                    mainContent(listVM: listVM, chatVM: chatVM)
                } else if let error = serverError {
                    errorView(error)
                } else {
                    loadingView
                }
            }
            .frame(minWidth: 700, minHeight: 500)
            .task { await startup() }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 650)
    }

    private func mainContent(listVM: ConversationListViewModel, chatVM: ChatViewModel) -> some View {
        NavigationSplitView {
            ConversationListView(viewModel: listVM) { conversationId in
                chatVM.conversationId = conversationId
                Task { await chatVM.loadMessages() }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { Task { await listVM.createConversation() } }) {
                        Image(systemName: "plus")
                    }
                    .help("New Chat")
                }
            }
        } detail: {
            ChatView(viewModel: chatVM)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { settingsVM.showSettings = true }) {
                            Image(systemName: "gearshape")
                        }
                        .help("Settings")
                    }
                }
        }
        .navigationTitle("apfel chat")
        .sheet(isPresented: $settingsVM.showSettings) {
            SettingsPanel(viewModel: settingsVM)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Starting on-device AI...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Retry") {
                serverError = nil
                Task { await startup() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
    }

    private func startup() async {
        // Initialize persistence
        do {
            let db = try SQLitePersistence()
            self.persistence = db

            // Start server
            guard let port = await serverManager.start() else {
                if case .failed(let msg) = serverManager.state {
                    serverError = msg
                } else {
                    serverError = "Failed to start server"
                }
                return
            }

            let service = ApfelChatService(port: port)
            self.chatService = service

            let stt = OnDeviceSpeechInput()
            let tts = OnDeviceSpeechOutput()

            let listVM = ConversationListViewModel(persistence: db)
            let chatVM = ChatViewModel(chatService: service, persistence: db, speechInput: stt, speechOutput: tts)
            chatVM.settings = settingsVM.toModelSettings()

            await listVM.loadConversations()

            // Select or create first conversation
            if listVM.conversations.isEmpty {
                await listVM.createConversation()
            }
            if let first = listVM.conversations.first {
                listVM.selectedId = first.id
                chatVM.conversationId = first.id
                await chatVM.loadMessages()
            }

            self.conversationListVM = listVM
            self.chatVM = chatVM
            self.isReady = true
        } catch {
            serverError = "Database error: \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift build 2>&1`
Expected: Build succeeds

- [ ] **Step 3: Run all tests**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test 2>&1`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add Sources/App/ApfelChatApp.swift
git commit -m "feat: ApfelChatApp — full app entry with server lifecycle, persistence, NavigationSplitView"
```

---

### Task 15: Release Infrastructure

**Files:**
- Create: `scripts/release.sh`

- [ ] **Step 1: Create release script**

Create `scripts/release.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>"
  exit 1
fi

REPO="Arthur-Ficial/apfel-chat"
BINARY="apfel-chat"
TAP_REPO="Arthur-Ficial/homebrew-tap"
TAP_DIR="/opt/homebrew/Library/Taps/arthur-ficial/homebrew-tap"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== apfel-chat release v${VERSION} ==="

echo "[1/6] Building release binary..."
cd "$PROJECT_DIR"
swift build -c release
BINARY_PATH="$PROJECT_DIR/.build/release/$BINARY"
[[ -f "$BINARY_PATH" ]] || { echo "Error: binary not found"; exit 1; }

echo "[2/6] Packaging tarball..."
STAGING="/tmp/apfel-chat-release-$$"
mkdir -p "$STAGING/$BINARY-${VERSION}"
cp "$BINARY_PATH" "$STAGING/$BINARY-${VERSION}/$BINARY"
TARBALL="$STAGING/$BINARY-${VERSION}-arm64-macos.tar.gz"
cd "$STAGING"
tar czf "$TARBALL" "$BINARY-${VERSION}"

echo "[3/6] Computing sha256..."
SHA256=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
echo "  SHA256: $SHA256"

echo "[4/6] Creating GitHub release v${VERSION}..."
cd "$PROJECT_DIR"
gh release create "v${VERSION}" "$TARBALL" \
  --repo "$REPO" \
  --title "apfel-chat v${VERSION}" \
  --notes "Release v${VERSION}

## Install
\`\`\`bash
brew tap Arthur-Ficial/tap
brew install apfel-chat
\`\`\`

Requires [apfel](https://github.com/Arthur-Ficial/apfel) installed on your Mac."

echo "[5/6] Generating Homebrew formula..."
FORMULA_PATH="$TAP_DIR/Formula/apfel-chat.rb"
cat > "$FORMULA_PATH" <<EOF
class ApfelChat < Formula
  desc "Super-fast, lightweight chat client for on-device AI via apfel"
  homepage "https://github.com/${REPO}"
  url "https://github.com/${REPO}/releases/download/v${VERSION}/${BINARY}-${VERSION}-arm64-macos.tar.gz"
  sha256 "${SHA256}"
  license "MIT"

  depends_on "arthur-ficial/tap/apfel"

  def install
    odie "apfel-chat requires a Mac with Apple Silicon." unless Hardware::CPU.arm?
    bin.install "apfel-chat"
  end

  def caveats
    <<~EOS
      apfel-chat requires apfel to be installed:
        brew install arthur-ficial/tap/apfel

      Run with:
        apfel-chat
    EOS
  end

  test do
    assert_predicate bin/"apfel-chat", :executable?
  end
end
EOF

echo "[6/6] Pushing formula to homebrew-tap..."
cd "$TAP_DIR"
git add "Formula/apfel-chat.rb"
git commit -m "apfel-chat ${VERSION}"
git push origin main

echo "=== Done! ==="
echo "brew tap Arthur-Ficial/tap && brew install apfel-chat"

rm -rf "$STAGING"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/release.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/release.sh
git commit -m "feat: release script — build, package, GitHub release, Homebrew formula"
```

---

### Task 16: Final Integration + All Tests Green

- [ ] **Step 1: Run full test suite**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift test 2>&1`
Expected: All tests PASS

- [ ] **Step 2: Run release build**

Run: `cd /Users/arthurficial/dev/apfel-chat && swift build -c release 2>&1`
Expected: Build succeeds

- [ ] **Step 3: Verify binary runs**

Run: `cd /Users/arthurficial/dev/apfel-chat && timeout 5 .build/release/apfel-chat 2>&1 || true`
Expected: App starts (may timeout since it's a GUI app, that's fine)

- [ ] **Step 4: Push to GitHub**

```bash
cd /Users/arthurficial/dev/apfel-chat
git push origin main
```

- [ ] **Step 5: Final commit if any fixes needed**

Run all tests one more time, fix anything that broke, commit.
