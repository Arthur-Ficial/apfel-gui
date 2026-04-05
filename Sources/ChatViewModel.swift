// ============================================================================
// ChatViewModel.swift — State management for the chat interface
// Talks to apfel --serve via APIClient. No AI logic here.
// ============================================================================

import Foundation
import SwiftUI


/// A single chat message with debug metadata.
struct ChatMsg: Identifiable {
    let id: String
    let role: String        // "user" or "assistant"
    var content: String     // grows during streaming
    let timestamp: Date
    var requestJSON: String?
    var responseJSON: String?
    var curlCommand: String?
    var durationMs: Int?
    var tokenCount: Int?
    var promptTokens: Int?
    var completionTokens: Int?
    var finishReason: String?
    var toolCalls: [APIClient.ToolCallAccumulator]?
    var errorType: String?
    var serverRequestId: String?    // matches /v1/logs entry ID
    var serverEvents: [String]?     // events from server-side log
    var isStreaming: Bool = false
    var includeInHistory: Bool = true
}

/// Observable state for the chat interface.
@Observable
@MainActor
class ChatViewModel {
    var messages: [ChatMsg] = []
    var currentInput: String = ""
    var systemPrompt: String = ""
    var isStreaming: Bool = false
    var selectedMessageId: String?
    var errorMessage: String?
    var errorType: String?
    var showDebugPanel: Bool = true
    var showLogPanel: Bool = true
    var debugAutoFollow: Bool = true
    var speakEnabled: Bool = false
    var isSelfDiscussing: Bool = false
    var showSelfDiscussion: Bool = false
    var showContextSettings: Bool = false
    var showModelSettings: Bool = false
    var showMCPSettings: Bool = false
    var mcpServerPaths: [String] = []
    var contextStrategyRaw: String = ContextStrategy.newestFirst.rawValue
    var contextMaxTurns: Int? = nil
    var contextOutputReserve: Int = 512

    // Model settings
    var temperature: Double? = nil
    var maxTokens: Int? = nil
    var seed: Int? = nil
    var jsonMode: Bool = false

    // Server info (fetched on startup)
    var serverVersion: String = ""
    var contextWindow: Int = 4096
    var modelAvailable: Bool = true
    var supportedLanguages: [String] = []
    var supportedParameters: [String] = []
    var unsupportedParameters: [String] = []
    var modelNotes: String = ""
    var activeRequests: Int = 0
    var serverStatus: String = "connecting"

    var contextStrategy: ContextStrategy {
        get { ContextStrategy(rawValue: contextStrategyRaw) ?? .newestFirst }
        set { contextStrategyRaw = newValue.rawValue }
    }

    var apiClient: APIClient
    let tts = TTSManager()
    let stt = STTManager()

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        Task { await fetchServerInfo() }
    }

    /// The currently selected message (for debug panel).
    var selectedMessage: ChatMsg? {
        guard let id = selectedMessageId else { return nil }
        return messages.first { $0.id == id }
    }

    /// Fetch server info from /health and /v1/models.
    func fetchServerInfo() async {
        if let health = await apiClient.fetchHealth() {
            serverVersion = health.version ?? ""
            contextWindow = health.context_window ?? 4096
            modelAvailable = health.model_available ?? true
            supportedLanguages = health.supported_languages ?? []
            activeRequests = health.active_requests ?? 0
            serverStatus = health.status
        }
        let models = await apiClient.fetchModels()
        if let model = models.first {
            if let cw = model.context_window { contextWindow = cw }
            supportedParameters = model.supported_parameters ?? []
            unsupportedParameters = model.unsupported_parameters ?? []
            modelNotes = model.notes ?? ""
        }
    }

    /// Send the current input as a message and stream the response.
    func send() async {
        let input = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !isStreaming else { return }

        // Build message history (before adding this message)
        var history = messages.filter { ($0.role == "user" || $0.role == "assistant") && $0.includeInHistory }
            .map { (role: $0.role, content: $0.content) }
        history.append((role: "user", content: input))

        // Build request params
        let currentStrategy = ContextStrategy(rawValue: contextStrategyRaw) ?? .newestFirst
        let strategy = currentStrategy == .newestFirst ? nil : currentStrategy.rawValue
        let maxTurns = contextMaxTurns
        let reserve = contextOutputReserve == 512 ? nil : contextOutputReserve
        let temp = temperature
        let maxTok = maxTokens
        let seedVal = seed
        let json = jsonMode

        let (stream, requestJSON) = apiClient.streamChatCompletion(
            messages: history,
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
            temperature: temp,
            maxTokens: maxTok,
            seed: seedVal,
            jsonMode: json,
            contextStrategy: strategy,
            contextMaxTurns: maxTurns,
            contextOutputReserve: reserve
        )

        // Build curl command for debug
        let port = 11434
        let curlCmd = buildCurlCommand(requestJSON: requestJSON, port: port)

        // Add user message (with request JSON attached)
        let userId = UUID().uuidString
        let userMsg = ChatMsg(
            id: userId,
            role: "user",
            content: input,
            timestamp: Date(),
            requestJSON: requestJSON,
            curlCommand: curlCmd
        )
        messages.append(userMsg)
        currentInput = ""
        isStreaming = true
        errorMessage = nil
        errorType = nil

        // Create assistant message placeholder
        let assistantId = UUID().uuidString
        messages.append(ChatMsg(
            id: assistantId,
            role: "assistant",
            content: "",
            timestamp: Date(),
            requestJSON: requestJSON,
            curlCommand: curlCmd,
            isStreaming: true
        ))

        let start = Date()

        do {
            for try await delta in stream {
                updateMessage(id: assistantId) { $0.content += delta }
            }

            let durationMs = Int(Date().timeIntervalSince(start) * 1000)
            let rawResponse = APIClient.lastRawSSEResponse
            let usage = APIClient.lastStreamingUsage
            let finishReason = APIClient.lastFinishReason
            let toolCalls = APIClient.lastToolCalls
            let requestId = APIClient.lastRequestId
            let assistantContent = messages.first(where: { $0.id == assistantId })?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            updateMessage(id: assistantId) { msg in
                msg.isStreaming = false
                msg.durationMs = durationMs
                msg.tokenCount = usage?.totalTokens
                msg.promptTokens = usage?.promptTokens
                msg.completionTokens = usage?.completionTokens
                msg.finishReason = finishReason
                msg.responseJSON = rawResponse
                msg.serverRequestId = requestId
                if !toolCalls.isEmpty {
                    msg.toolCalls = toolCalls
                    var toolContent = ""
                    for tc in toolCalls {
                        toolContent += "\n\n[Tool Call: \(tc.functionName)]\n\(tc.arguments)"
                    }
                    if !toolContent.isEmpty && assistantContent.isEmpty {
                        msg.content = toolContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }

            // Fetch server-side events for this request (async, non-blocking)
            if let reqId = requestId {
                Task {
                    if let logEntry = await apiClient.fetchLogEntry(requestId: reqId) {
                        updateMessage(id: assistantId) { $0.serverEvents = logEntry.events }
                    }
                }
            }

            if shouldExcludeTurnFromHistory(assistantContent) {
                updateMessage(id: userId) { $0.includeInHistory = false }
                updateMessage(id: assistantId) { $0.includeInHistory = false }
                if assistantContent.isEmpty && toolCalls.isEmpty {
                    updateMessage(id: assistantId) { $0.content = "Error: Empty response from model." }
                    errorMessage = "Empty response from model."
                }
            }

            // Auto-follow: select the latest assistant message in debug panel
            if debugAutoFollow {
                selectedMessageId = assistantId
            }

            // Speak the response if TTS is enabled
            if speakEnabled, let content = messages.first(where: { $0.id == assistantId })?.content,
               !content.isEmpty, !content.hasPrefix("Error:"), !content.hasPrefix("[Tool Call:") {
                tts.speak(content)
            }

            // Refresh server info (active requests count)
            Task { await fetchServerInfo() }

        } catch let error as APIClient.StreamError {
            updateMessage(id: assistantId) { msg in
                msg.content = "Error: \(error.message)"
                msg.isStreaming = false
                msg.includeInHistory = false
                msg.errorType = error.errorType
                msg.responseJSON = APIClient.lastRawSSEResponse
            }
            updateMessage(id: userId) { $0.includeInHistory = false }
            errorMessage = error.message
            errorType = error.errorType
        } catch {
            updateMessage(id: assistantId) { msg in
                msg.content = "Error: \(error.localizedDescription)"
                msg.isStreaming = false
                msg.includeInHistory = false
                msg.responseJSON = APIClient.lastRawSSEResponse
            }
            updateMessage(id: userId) { $0.includeInHistory = false }
            errorMessage = error.localizedDescription
        }

        isStreaming = false
    }

    /// Clear all messages.
    func clear() {
        messages.removeAll()
        selectedMessageId = nil
        errorMessage = nil
        errorType = nil
    }

    // MARK: - Helpers

    private func updateMessage(id: String, update: (inout ChatMsg) -> Void) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            update(&messages[idx])
        }
    }

    private func buildCurlCommand(requestJSON: String, port: Int) -> String {
        let compact = requestJSON.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "  ", with: "")
        return "curl -X POST http://127.0.0.1:\(port)/v1/chat/completions \\\n  -H \"Content-Type: application/json\" \\\n  -d '\(compact)'"
    }

    private func shouldExcludeTurnFromHistory(_ assistantContent: String) -> Bool {
        let lowered = assistantContent.lowercased()
        if assistantContent.isEmpty { return true }
        let refusalPatterns = [
            "can't assist with that request",
            "cannot assist with that request",
            "can't help with that request",
            "cannot help with that request",
            "i'm sorry, but i can't assist",
            "i'm sorry, but i cannot assist",
            "unsafe",
            "safety reasons",
            "guardrail",
            "error:"
        ]
        return refusalPatterns.contains { lowered.contains($0) }
    }

    // MARK: - Voice Input

    func toggleListening() {
        if stt.isListening {
            errorMessage = nil
            let transcript = stt.stopListening()
            if !transcript.isEmpty {
                currentInput += (currentInput.isEmpty ? "" : " ") + transcript
                Task {
                    await send()
                }
            }
        } else {
            Task {
                do {
                    errorMessage = nil
                    let authorized = await stt.requestPermissions()
                    if authorized {
                        stt.startListening()
                        if let err = stt.errorMessage {
                            errorMessage = err
                        }
                    } else {
                        errorMessage = stt.errorMessage ?? "Microphone/speech permission denied. Enable in System Settings → Privacy & Security."
                    }
                }
            }
        }
    }

    // MARK: - Self-Discussion

    /// AI debates itself for N turns on a topic, alternating between two system prompts.
    func startSelfDiscussion(
        topic: String,
        turns: Int,
        systemA: String,
        systemB: String,
        languageCodeA: String,
        languageCodeB: String
    ) async {
        guard !isSelfDiscussing else { return }
        isSelfDiscussing = true
        isStreaming = true

        // Add the topic as a user message
        let topicMsg = ChatMsg(
            id: UUID().uuidString,
            role: "user",
            content: "Topic: \(topic)",
            timestamp: Date()
        )
        messages.append(topicMsg)

        var previousResponse = topic

        for turn in 1...turns {
            let isA = turn % 2 == 1
            let systemPromptForTurn = localizedSystemPrompt(
                base: isA ? systemA : systemB,
                languageCode: isA ? languageCodeA : languageCodeB
            )
            let speechLanguage = isA ? languageCodeA : languageCodeB

            // Create assistant placeholder
            let msgId = UUID().uuidString
            messages.append(ChatMsg(
                id: msgId,
                role: "assistant",
                content: "",
                timestamp: Date(),
                isStreaming: true
            ))

            let prompt = turn == 1
                ? topic
                : "The previous speaker said: \"\(previousResponse)\"\n\nNow respond to this."

            let history: [(role: String, content: String)] = [(role: "user", content: prompt)]
            let (stream, requestJSON) = apiClient.streamChatCompletion(
                messages: history,
                systemPrompt: systemPromptForTurn,
                temperature: temperature,
                maxTokens: maxTokens,
                seed: seed
            )

            updateMessage(id: msgId) { $0.requestJSON = requestJSON }

            let start = Date()
            do {
                for try await delta in stream {
                    updateMessage(id: msgId) { $0.content += delta }
                }

                let durationMs = Int(Date().timeIntervalSince(start) * 1000)
                let rawResponse = APIClient.lastRawSSEResponse
                let usage = APIClient.lastStreamingUsage
                updateMessage(id: msgId) { msg in
                    msg.isStreaming = false
                    msg.durationMs = durationMs
                    msg.tokenCount = usage?.totalTokens
                    msg.promptTokens = usage?.promptTokens
                    msg.completionTokens = usage?.completionTokens
                    msg.finishReason = APIClient.lastFinishReason
                    msg.responseJSON = rawResponse
                }

                previousResponse = messages.first(where: { $0.id == msgId })?.content ?? ""

                if debugAutoFollow {
                    selectedMessageId = msgId
                }

                // Speak if enabled
                if speakEnabled, !previousResponse.isEmpty {
                    tts.speak(previousResponse, languageCode: speechLanguage, voiceVariant: isA ? 0 : 1)
                    while tts.isSpeaking {
                        try? await Task.sleep(for: .milliseconds(200))
                    }
                }

            } catch {
                updateMessage(id: msgId) { msg in
                    msg.content = "Error: \(error.localizedDescription)"
                    msg.isStreaming = false
                }
                break
            }
        }

        isSelfDiscussing = false
        isStreaming = false
    }

    private func localizedSystemPrompt(base: String, languageCode: String) -> String {
        let languageLabel = TTSManager.preferredVoices.first(where: { $0.languageCode == languageCode })?.label ?? languageCode
        return "\(base)\n\nRespond only in \(languageLabel)."
    }
}
