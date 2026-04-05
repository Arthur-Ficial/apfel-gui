// ============================================================================
// APIClient.swift — HTTP client to apfel --serve (v0.7.7+)
// Part of apfel GUI — talks to the server via OpenAI-compatible API
// NO FoundationModels import — all AI logic lives in the server.
// ============================================================================

import Foundation

/// HTTP client that talks to the apfel server's OpenAI-compatible API.
/// This is the ONLY file that makes network requests. Pure URLSession.
/// Works with any OpenAI-compatible server — not locked to apfel.
final class APIClient: @unchecked Sendable {
    struct StreamError: LocalizedError {
        let message: String
        let errorType: String?
        var errorDescription: String? { message }
    }

    var baseURL: URL
    var modelName: String

    init(port: Int, model: String = "apple-foundationmodel") {
        self.baseURL = URL(string: "http://127.0.0.1:\(port)")!
        self.modelName = model
    }

    init(baseURL: URL, model: String = "apple-foundationmodel") {
        self.baseURL = baseURL
        self.modelName = model
    }

    // MARK: - Health Check

    struct HealthResponse: Decodable, Sendable {
        let status: String
        let model: String?
        let version: String?
        let active_requests: Int?
        let context_window: Int?
        let model_available: Bool?
        let supported_languages: [String]?
    }

    /// Check server health. Returns nil if unreachable.
    func healthCheck() async -> Bool {
        guard let url = URL(string: "/health", relativeTo: baseURL) else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Fetch full health info from the server.
    func fetchHealth() async -> HealthResponse? {
        guard let url = URL(string: "/health", relativeTo: baseURL) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(HealthResponse.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Models

    struct ModelListResponse: Decodable, Sendable {
        let data: [ModelInfo]
    }

    struct ModelInfo: Decodable, Sendable {
        let id: String
        let context_window: Int?
        let supported_parameters: [String]?
        let unsupported_parameters: [String]?
        let notes: String?
    }

    func fetchModels() async -> [ModelInfo] {
        guard let url = URL(string: "/v1/models", relativeTo: baseURL) else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ModelListResponse.self, from: data)
            return response.data
        } catch {
            return []
        }
    }

    // MARK: - Structured Errors

    struct APIErrorResponse: Decodable, Sendable {
        let error: APIErrorDetail
    }

    struct APIErrorDetail: Decodable, Sendable {
        let message: String
        let type: String?
        let param: String?
        let code: String?
    }

    // MARK: - Chat Completion Models

    struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let stream: Bool
        let temperature: Double?
        let max_tokens: Int?
        let seed: Int?
        let response_format: ResponseFormat?
        let x_context_strategy: String?
        let x_context_max_turns: Int?
        let x_context_output_reserve: Int?

        struct Message: Encodable {
            let role: String
            let content: String
        }
        struct ResponseFormat: Encodable {
            let type: String
        }
    }

    struct ChatResponse: Decodable {
        let id: String
        let choices: [Choice]
        let usage: Usage?

        struct Choice: Decodable {
            let message: ResponseMessage
            let finish_reason: String?
        }
        struct ResponseMessage: Decodable {
            let role: String
            let content: String?
            let tool_calls: [ToolCallResponse]?
        }
        struct ToolCallResponse: Decodable {
            let id: String?
            let type: String?
            let function: ToolCallFunction?
        }
        struct ToolCallFunction: Decodable {
            let name: String?
            let arguments: String?
        }
        struct Usage: Decodable {
            let prompt_tokens: Int?
            let completion_tokens: Int?
            let total_tokens: Int?
        }
    }

    // MARK: - Chat Completion (Non-Streaming)

    func chatCompletion(
        messages: [(role: String, content: String)],
        systemPrompt: String?,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        seed: Int? = nil,
        jsonMode: Bool = false,
        contextStrategy: String? = nil,
        contextMaxTurns: Int? = nil,
        contextOutputReserve: Int? = nil
    ) async throws -> (response: ChatResponse, requestJSON: String, responseJSON: String, durationMs: Int) {
        let start = Date()
        let apiMessages = buildMessages(messages: messages, systemPrompt: systemPrompt)
        let request = ChatRequest(
            model: modelName,
            messages: apiMessages,
            stream: false,
            temperature: temperature,
            max_tokens: maxTokens,
            seed: seed,
            response_format: jsonMode ? .init(type: "json_object") : nil,
            x_context_strategy: contextStrategy,
            x_context_max_turns: contextMaxTurns,
            x_context_output_reserve: contextOutputReserve
        )
        let requestJSON = prettyJSON(request)

        var urlRequest = URLRequest(url: URL(string: "/v1/chat/completions", relativeTo: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, httpResponse) = try await URLSession.shared.data(for: urlRequest)
        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        let responseJSON = String(data: data, encoding: .utf8) ?? "{}"

        // Check for structured error response
        if let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode, statusCode >= 400 {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw StreamError(
                    message: apiError.error.message,
                    errorType: apiError.error.type
                )
            }
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return (decoded, requestJSON, prettyFormatJSON(responseJSON), durationMs)
    }

    // MARK: - Chat Completion (Streaming)

    /// Collected raw SSE lines from the last streaming request.
    nonisolated(unsafe) static var lastRawSSEResponse: String = ""

    /// Request ID from the last streaming response (matches /v1/logs entry).
    nonisolated(unsafe) static var lastRequestId: String?

    /// Usage stats from the last streaming response.
    nonisolated(unsafe) static var lastStreamingUsage: StreamUsage?

    /// Finish reason from the last streaming response.
    nonisolated(unsafe) static var lastFinishReason: String?

    /// Tool calls accumulated from the last streaming response.
    nonisolated(unsafe) static var lastToolCalls: [ToolCallAccumulator] = []

    struct StreamUsage: Sendable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
    }

    struct ToolCallAccumulator: Sendable {
        var id: String
        var functionName: String
        var arguments: String
    }

    func streamChatCompletion(
        messages: [(role: String, content: String)],
        systemPrompt: String?,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        seed: Int? = nil,
        jsonMode: Bool = false,
        contextStrategy: String? = nil,
        contextMaxTurns: Int? = nil,
        contextOutputReserve: Int? = nil
    ) -> (stream: AsyncThrowingStream<String, Error>, requestJSON: String) {
        let apiMessages = buildMessages(messages: messages, systemPrompt: systemPrompt)
        let request = ChatRequest(
            model: modelName,
            messages: apiMessages,
            stream: true,
            temperature: temperature,
            max_tokens: maxTokens,
            seed: seed,
            response_format: jsonMode ? .init(type: "json_object") : nil,
            x_context_strategy: contextStrategy,
            x_context_max_turns: contextMaxTurns,
            x_context_output_reserve: contextOutputReserve
        )
        let requestJSON = prettyJSON(request)
        let url = URL(string: "/v1/chat/completions", relativeTo: baseURL)!

        let stream = AsyncThrowingStream<String, Error> { continuation in
            Task {
                var rawLines: [String] = []
                var toolCalls: [Int: ToolCallAccumulator] = [:]
                do {
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, httpResponse) = try await URLSession.shared.bytes(for: urlRequest)

                    // Check for non-200 status (error response as JSON, not SSE)
                    if let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode, statusCode >= 400 {
                        var errorData = Data()
                        for try await byte in bytes {
                            errorData.append(byte)
                        }
                        let errorJSON = String(data: errorData, encoding: .utf8) ?? ""
                        rawLines.append(errorJSON)
                        APIClient.lastRawSSEResponse = rawLines.joined(separator: "\n")

                        if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: errorData) {
                            continuation.finish(throwing: StreamError(
                                message: apiError.error.message,
                                errorType: apiError.error.type
                            ))
                        } else {
                            continuation.finish(throwing: StreamError(
                                message: Self.userFacingErrorMessage(errorJSON),
                                errorType: nil
                            ))
                        }
                        return
                    }

                    APIClient.lastStreamingUsage = nil
                    APIClient.lastFinishReason = nil
                    APIClient.lastToolCalls = []
                    APIClient.lastRequestId = nil

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: [DONE]") {
                            rawLines.append("data: [DONE]")
                            break
                        }
                        if line.hasPrefix("data: ") {
                            let json = String(line.dropFirst(6))
                            let prettyChunk = Self.prettyFormatInline(json)
                            rawLines.append("data: \(prettyChunk)")

                            if let data = json.data(using: .utf8) {
                                // Check for usage stats
                                if let usageData = try? JSONDecoder().decode(StreamUsageChunk.self, from: data) {
                                    APIClient.lastStreamingUsage = StreamUsage(
                                        promptTokens: usageData.usage.prompt_tokens,
                                        completionTokens: usageData.usage.completion_tokens,
                                        totalTokens: usageData.usage.total_tokens
                                    )
                                    continue
                                }

                                // Check for structured error in stream
                                if let errorChunk = try? JSONDecoder().decode(StreamErrorResponse.self, from: data) {
                                    APIClient.lastRawSSEResponse = rawLines.joined(separator: "\n\n")
                                    continuation.finish(throwing: StreamError(
                                        message: errorChunk.error.message,
                                        errorType: errorChunk.error.type
                                    ))
                                    return
                                }

                                // Legacy simple error format
                                if let errorChunk = try? JSONDecoder().decode(StreamErrorChunkLegacy.self, from: data) {
                                    APIClient.lastRawSSEResponse = rawLines.joined(separator: "\n\n")
                                    continuation.finish(throwing: StreamError(
                                        message: Self.userFacingErrorMessage(errorChunk.error),
                                        errorType: nil
                                    ))
                                    return
                                }

                                // Parse content chunk
                                if let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data) {
                                    // Capture request ID (same across all chunks)
                                    if let chunkId = chunk.id, APIClient.lastRequestId == nil {
                                        APIClient.lastRequestId = chunkId
                                    }
                                    if let choice = chunk.choices.first {
                                        // Capture finish_reason
                                        if let reason = choice.finish_reason {
                                            APIClient.lastFinishReason = reason
                                        }
                                        // Yield content
                                        if let content = choice.delta.content {
                                            continuation.yield(content)
                                        }
                                        // Accumulate tool calls
                                        if let deltaToolCalls = choice.delta.tool_calls {
                                            for tc in deltaToolCalls {
                                                let idx = tc.index ?? 0
                                                if toolCalls[idx] == nil {
                                                    toolCalls[idx] = ToolCallAccumulator(
                                                        id: tc.id ?? "",
                                                        functionName: tc.function?.name ?? "",
                                                        arguments: ""
                                                    )
                                                }
                                                if let name = tc.function?.name, !name.isEmpty {
                                                    toolCalls[idx]?.functionName = name
                                                }
                                                if let id = tc.id, !id.isEmpty {
                                                    toolCalls[idx]?.id = id
                                                }
                                                if let args = tc.function?.arguments {
                                                    toolCalls[idx]?.arguments += args
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    APIClient.lastRawSSEResponse = rawLines.joined(separator: "\n\n")
                    APIClient.lastToolCalls = toolCalls.sorted(by: { $0.key < $1.key }).map(\.value)
                    continuation.finish()
                } catch {
                    APIClient.lastRawSSEResponse = rawLines.joined(separator: "\n") + "\nerror: \(error.localizedDescription)"
                    continuation.finish(throwing: error)
                }
            }
        }

        return (stream, requestJSON)
    }

    // MARK: - Stream Chunk Types

    private struct StreamChunk: Decodable {
        let id: String?
        let choices: [ChunkChoice]
        struct ChunkChoice: Decodable {
            let delta: Delta
            let finish_reason: String?
        }
        struct Delta: Decodable {
            let role: String?
            let content: String?
            let tool_calls: [ToolCallDelta]?
        }
        struct ToolCallDelta: Decodable {
            let index: Int?
            let id: String?
            let type: String?
            let function: ToolCallFunctionDelta?
        }
        struct ToolCallFunctionDelta: Decodable {
            let name: String?
            let arguments: String?
        }
    }

    private struct StreamErrorResponse: Decodable {
        let error: APIErrorDetail
    }

    private struct StreamErrorChunkLegacy: Decodable {
        let error: String
    }

    private struct StreamUsageChunk: Decodable {
        let usage: Usage
        struct Usage: Decodable {
            let prompt_tokens: Int
            let completion_tokens: Int
            let total_tokens: Int
        }
    }

    // MARK: - Logs

    struct LogEntry: Decodable, Identifiable {
        let id: String
        let timestamp: String
        let method: String
        let path: String
        let status: Int
        let duration_ms: Int
        let stream: Bool
        let estimated_tokens: Int?
        let error: String?
        let request_body: String?
        let response_body: String?
        let events: [String]?
    }

    struct LogListResponse: Decodable {
        let count: Int
        let data: [LogEntry]
    }

    func fetchLogs(errorsOnly: Bool = false, limit: Int = 100) async throws -> [LogEntry] {
        var urlStr = "/v1/logs?limit=\(limit)"
        if errorsOnly { urlStr += "&errors=true" }
        let url = URL(string: urlStr, relativeTo: baseURL)!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(LogListResponse.self, from: data)
        return response.data
    }

    /// Find the log entry for a request. Tries exact ID match first, then falls back to
    /// the most recent entry with matching characteristics (MCP auto-execute creates new IDs).
    func fetchLogEntry(requestId: String) async -> LogEntry? {
        guard let entries = try? await fetchLogs(limit: 20) else { return nil }
        // Exact match (v0.7.x format)
        if let match = entries.first(where: { $0.id == requestId + "-stream" })
            ?? entries.first(where: { $0.id == requestId }) {
            return match
        }
        // MCP auto-execute creates a new internal request with a different ID.
        // Fall back to the most recent completed stream entry.
        return entries.first(where: { $0.stream && $0.status == 200 })
    }

    // MARK: - Stats

    struct ServerStats: Decodable {
        let uptime_seconds: Int
        let total_requests: Int
        let total_errors: Int
        let avg_duration_ms: Int
        let requests_per_minute: Double
        let estimated_tokens_total: Int?
        let active_requests: Int
        let max_concurrent: Int
    }

    func fetchStats() async throws -> ServerStats {
        let url = URL(string: "/v1/logs/stats", relativeTo: baseURL)!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ServerStats.self, from: data)
    }

    // MARK: - Helpers

    private func buildMessages(
        messages: [(role: String, content: String)],
        systemPrompt: String?
    ) -> [ChatRequest.Message] {
        var apiMessages: [ChatRequest.Message] = []
        if let sys = systemPrompt, !sys.isEmpty {
            apiMessages.append(.init(role: "system", content: sys))
        }
        for msg in messages {
            apiMessages.append(.init(role: msg.role, content: msg.content))
        }
        return apiMessages
    }

    private func prettyJSON<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    /// Pretty-print a single JSON string (static, for use in closures).
    static func prettyFormatInline(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return raw }
        return str
    }

    static func userFacingErrorMessage(_ raw: String) -> String {
        let lowered = raw.lowercased()
        if lowered.contains("guardrail") || lowered.contains("safety") {
            return "Content blocked by Apple's safety guardrails. Try rephrasing."
        }
        if lowered.contains("context") && lowered.contains("exceed") {
            return "Input exceeds the context window. Shorten your conversation or clear history."
        }
        if lowered.contains("rate limit") {
            return "Rate limited by Apple Intelligence. Wait a moment and try again."
        }
        if lowered.contains("concurrent") || lowered.contains("capacity") {
            return "Server at max concurrent capacity. Try again in a moment."
        }
        return raw
    }

    static func isSafetyError(_ raw: String) -> Bool {
        let lowered = raw.lowercased()
        return lowered.contains("unsafe") || lowered.contains("safety") || lowered.contains("guardrail")
    }

    /// Classify an error type string into a user-friendly category.
    static func errorCategory(_ errorType: String?) -> String {
        switch errorType {
        case "content_policy_violation": return "Content Policy"
        case "context_length_exceeded": return "Context Overflow"
        case "rate_limit_error": return "Rate Limited"
        case "invalid_request_error": return "Invalid Request"
        case "server_error": return "Server Error"
        default: return errorType ?? "Error"
        }
    }

    private func prettyFormatJSON(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return raw }
        return str
    }
}
