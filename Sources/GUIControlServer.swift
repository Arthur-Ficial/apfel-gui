// ============================================================================
// GUIControlServer.swift - HTTP API for full programmatic GUI control
// Start with: apfel-gui --api
// Every GUI action is controllable via HTTP on port 11439.
// ============================================================================

import Foundation
import AVFoundation

/// HTTP server for AI-first control of apfel-gui.
/// Every action the user can take in the GUI can be done via this API.
@MainActor
class GUIControlServer {
    let viewModel: ChatViewModel
    private var serverTask: Task<Void, Never>?

    static nonisolated let port: UInt16 = 11439

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        let vm = viewModel
        let p = Self.port
        serverTask = Task.detached {
            guard let listener = createListenerSocket(port: p) else {
                printStderr("GUI API: failed to start on port \(p)")
                return
            }
            printStderr("GUI API: http://127.0.0.1:\(p)")

            while true {
                guard let client = try? await acceptSocket(listener) else { continue }
                Task.detached {
                    await Self.handleConnection(client, viewModel: vm)
                }
            }
        }
    }

    // MARK: - Request Handling

    nonisolated private static func handleConnection(_ client: Int32, viewModel vm: ChatViewModel) async {
        var buffer = [UInt8](repeating: 0, count: 16384)
        let n = read(client, &buffer, buffer.count)
        guard n > 0 else { close(client); return }
        let request = String(bytes: buffer[0..<n], encoding: .utf8) ?? ""

        let firstLine = request.split(separator: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { close(client); return }
        let method = String(parts[0])
        let path = String(parts[1])

        let body: String
        if let bodyStart = request.range(of: "\r\n\r\n") {
            body = String(request[bodyStart.upperBound...])
        } else {
            body = ""
        }

        let response: String
        switch (method, path) {

        // === STATE ===
        case ("GET", "/state"):
            response = await getState(vm)
        case ("GET", "/messages"):
            response = await getMessages(vm)
        case ("GET", "/debug"):
            response = await getDebugInfo(vm)

        // === CHAT ===
        case ("POST", "/send"):
            response = await sendMessage(body, vm: vm)
        case ("POST", "/clear"):
            await MainActor.run { vm.clear() }
            response = ok()
        case ("POST", "/system-prompt"):
            response = await setSystemPrompt(body, vm: vm)

        // === SETTINGS ===
        case ("POST", "/settings"):
            response = await updateSettings(body, vm: vm)
        case ("GET", "/settings"):
            response = await getSettings(vm)

        // === SPEECH ===
        case ("GET", "/voices"):
            response = getVoices(vm)
        case ("POST", "/speak"):
            response = await speak(body, vm: vm)
        case ("POST", "/stop-speaking"):
            await MainActor.run { vm.tts.stop() }
            response = ok()

        // === UI PANELS ===
        case ("POST", "/toggle-debug"):
            await MainActor.run { vm.showDebugPanel.toggle() }
            response = await ok(["debug_panel": MainActor.run { vm.showDebugPanel }])
        case ("POST", "/toggle-logs"):
            await MainActor.run { vm.showLogPanel.toggle() }
            response = await ok(["log_panel": MainActor.run { vm.showLogPanel }])
        case ("POST", "/inspect"):
            response = await inspectMessage(body, vm: vm)

        // === SELF-DISCUSSION ===
        case ("POST", "/self-discuss"):
            response = await startSelfDiscussion(body, vm: vm)

        // === HELP ===
        case (_, "/"):
            response = helpResponse()
        default:
            response = helpResponse()
        }

        let http = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\nContent-Length: \(response.utf8.count)\r\n\r\n\(response)"
        _ = http.withCString { write(client, $0, Int(strlen($0))) }
        close(client)
    }

    // MARK: - State

    private static func getState(_ vm: ChatViewModel) async -> String {
        await MainActor.run {
            jsonDict([
                "messages_count": vm.messages.count,
                "is_streaming": vm.isStreaming,
                "speech_language": vm.speechLanguage,
                "speech_enabled": vm.speakEnabled,
                "selected_voice_id": vm.selectedVoiceId ?? "auto",
                "mcp_servers": vm.mcpServerPaths,
                "server_version": vm.serverVersion,
                "context_window": vm.contextWindow,
                "model_available": vm.modelAvailable,
                "debug_panel": vm.showDebugPanel,
                "log_panel": vm.showLogPanel,
                "system_prompt": vm.systemPrompt,
                "temperature": vm.temperature as Any,
                "max_tokens": vm.maxTokens as Any,
                "seed": vm.seed as Any,
                "json_mode": vm.jsonMode,
                "context_strategy": vm.contextStrategyRaw,
                "server_launch_command": vm.serverLaunchCommand,
            ])
        }
    }

    private static func getMessages(_ vm: ChatViewModel) async -> String {
        await MainActor.run {
            let msgs = vm.messages.map { msg -> [String: Any] in
                var m: [String: Any] = [
                    "id": msg.id, "role": msg.role, "content": msg.content,
                    "include_in_history": msg.includeInHistory
                ]
                if let ms = msg.durationMs { m["duration_ms"] = ms }
                if let tokens = msg.tokenCount { m["tokens"] = tokens }
                if let pt = msg.promptTokens { m["prompt_tokens"] = pt }
                if let ct = msg.completionTokens { m["completion_tokens"] = ct }
                if let reason = msg.finishReason { m["finish_reason"] = reason }
                if let errorType = msg.errorType { m["error_type"] = errorType }
                if let reqId = msg.serverRequestId { m["server_request_id"] = reqId }
                if let events = msg.serverEvents { m["server_events"] = events }
                if let toolCalls = msg.toolCalls {
                    m["tool_calls"] = toolCalls.map { ["name": $0.functionName, "arguments": $0.arguments, "id": $0.id] }
                }
                return m
            }
            return jsonDict(["messages": msgs, "count": msgs.count])
        }
    }

    private static func getDebugInfo(_ vm: ChatViewModel) async -> String {
        await MainActor.run {
            guard let msg = vm.selectedMessage else {
                return jsonDict(["selected": false])
            }
            var d: [String: Any] = [
                "selected": true, "id": msg.id, "role": msg.role, "content": msg.content,
            ]
            if let json = msg.requestJSON { d["request_json"] = json }
            if let json = msg.responseJSON { d["response_json"] = json }
            if let curl = msg.curlCommand { d["curl_command"] = curl }
            if let ms = msg.durationMs { d["duration_ms"] = ms }
            if let tokens = msg.tokenCount { d["tokens"] = tokens }
            if let reason = msg.finishReason { d["finish_reason"] = reason }
            if let events = msg.serverEvents { d["server_events"] = events }
            if let toolCalls = msg.toolCalls {
                d["tool_calls"] = toolCalls.map { ["name": $0.functionName, "arguments": $0.arguments] }
            }
            d["server_launch_command"] = vm.serverLaunchCommand
            return jsonDict(d)
        }
    }

    // MARK: - Chat

    private static func sendMessage(_ body: String, vm: ChatViewModel) async -> String {
        guard let obj = parseJSON(body), let message = obj["message"] as? String else {
            return err("Need {\"message\": \"text\"}")
        }
        await MainActor.run { vm.currentInput = message }
        await vm.send()
        return await MainActor.run {
            guard let msg = vm.messages.last else { return ok() }
            return jsonDict([
                "status": "ok", "role": msg.role, "content": msg.content,
                "finish_reason": msg.finishReason ?? "unknown",
                "tokens": msg.tokenCount ?? 0,
                "duration_ms": msg.durationMs ?? 0,
                "server_events": msg.serverEvents ?? [],
                "tool_calls": (msg.toolCalls ?? []).map { ["name": $0.functionName, "arguments": $0.arguments] },
            ])
        }
    }

    private static func setSystemPrompt(_ body: String, vm: ChatViewModel) async -> String {
        guard let obj = parseJSON(body), let prompt = obj["prompt"] as? String else {
            return err("Need {\"prompt\": \"text\"}")
        }
        await MainActor.run { vm.systemPrompt = prompt }
        return ok()
    }

    // MARK: - Settings

    private static func getSettings(_ vm: ChatViewModel) async -> String {
        await MainActor.run {
            jsonDict([
                "speech_language": vm.speechLanguage,
                "speech_enabled": vm.speakEnabled,
                "selected_voice_id": vm.selectedVoiceId ?? "auto",
                "temperature": vm.temperature as Any,
                "max_tokens": vm.maxTokens as Any,
                "seed": vm.seed as Any,
                "json_mode": vm.jsonMode,
                "context_strategy": vm.contextStrategyRaw,
                "context_max_turns": vm.contextMaxTurns as Any,
                "context_output_reserve": vm.contextOutputReserve,
            ])
        }
    }

    private static func updateSettings(_ body: String, vm: ChatViewModel) async -> String {
        guard let obj = parseJSON(body) else { return err("Invalid JSON") }
        await MainActor.run {
            if let v = obj["speech_language"] as? String { vm.speechLanguage = v }
            if let v = obj["voice_id"] as? String { vm.selectedVoiceId = v == "auto" ? nil : v }
            if let v = obj["speak_enabled"] as? Bool { vm.speakEnabled = v }
            if let v = obj["temperature"] as? Double { vm.temperature = v }
            if let _ = obj["temperature"] as? NSNull { vm.temperature = nil }
            if let v = obj["max_tokens"] as? Int { vm.maxTokens = v }
            if let _ = obj["max_tokens"] as? NSNull { vm.maxTokens = nil }
            if let v = obj["seed"] as? Int { vm.seed = v }
            if let _ = obj["seed"] as? NSNull { vm.seed = nil }
            if let v = obj["json_mode"] as? Bool { vm.jsonMode = v }
            if let v = obj["context_strategy"] as? String { vm.contextStrategyRaw = v }
            if let v = obj["context_max_turns"] as? Int { vm.contextMaxTurns = v }
            if let v = obj["context_output_reserve"] as? Int { vm.contextOutputReserve = v }
            if let v = obj["system_prompt"] as? String { vm.systemPrompt = v }
        }
        return ok()
    }

    // MARK: - Speech

    nonisolated private static func getVoices(_ vm: ChatViewModel) -> String {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        var result: [[String: Any]] = []
        for v in voices.sorted(by: { ($0.language, $0.quality.rawValue) < ($1.language, $1.quality.rawValue) }) {
            result.append(["name": v.name, "language": v.language, "quality": v.quality.rawValue, "identifier": v.identifier])
        }
        return jsonDict(["voices": result, "count": result.count])
    }

    private static func speak(_ body: String, vm: ChatViewModel) async -> String {
        guard let obj = parseJSON(body), let text = obj["text"] as? String else {
            return err("Need {\"text\": \"...\"}")
        }
        let voiceId = obj["voice_id"] as? String
        let lang = obj["language"] as? String
        await MainActor.run {
            vm.tts.speak(text, languageCode: lang ?? vm.speechLanguage, voiceId: voiceId ?? vm.selectedVoiceId)
        }
        return jsonDict(["status": "speaking", "text": text])
    }

    // MARK: - UI Panels

    private static func inspectMessage(_ body: String, vm: ChatViewModel) async -> String {
        guard let obj = parseJSON(body) else { return err("Need {\"id\": \"msg_id\"} or {\"index\": 0}") }
        await MainActor.run {
            if let id = obj["id"] as? String {
                vm.selectedMessageId = id
                vm.showDebugPanel = true
            } else if let index = obj["index"] as? Int, index >= 0, index < vm.messages.count {
                vm.selectedMessageId = vm.messages[index].id
                vm.showDebugPanel = true
            }
        }
        return await getDebugInfo(vm)
    }

    // MARK: - Self-Discussion

    private static func startSelfDiscussion(_ body: String, vm: ChatViewModel) async -> String {
        guard let obj = parseJSON(body), let topic = obj["topic"] as? String else {
            return err("Need {\"topic\": \"...\"}")
        }
        let turns = obj["turns"] as? Int ?? 3
        let systemA = obj["system_a"] as? String ?? "Argue strongly IN FAVOR of this topic."
        let systemB = obj["system_b"] as? String ?? "Argue strongly AGAINST this topic."
        let langA = obj["language_a"] as? String ?? "en-US"
        let langB = obj["language_b"] as? String ?? "en-US"
        await vm.startSelfDiscussion(topic: topic, turns: turns, systemA: systemA, systemB: systemB, languageCodeA: langA, languageCodeB: langB)
        return await getMessages(vm)
    }

    // MARK: - Help

    nonisolated private static func helpResponse() -> String {
        jsonDict([
            "name": "apfel-gui control API",
            "usage": "Start with: apfel-gui --api",
            "endpoints": [
                "GET  /              Help (this response)",
                "GET  /state         Full app state",
                "GET  /messages      All messages with full metadata",
                "GET  /debug         Debug inspector for selected message",
                "GET  /settings      Current settings",
                "GET  /voices        All installed TTS voices",
                "POST /send          Send message: {\"message\": \"text\"}",
                "POST /clear         Clear chat",
                "POST /system-prompt Set system prompt: {\"prompt\": \"text\"}",
                "POST /settings      Update settings: {\"temperature\": 0.7, ...}",
                "POST /speak         Speak text: {\"text\": \"...\", \"voice_id\": \"...\"}",
                "POST /stop-speaking Stop TTS",
                "POST /toggle-debug  Toggle debug panel",
                "POST /toggle-logs   Toggle log viewer",
                "POST /inspect       Inspect message: {\"index\": 0} or {\"id\": \"...\"}",
                "POST /self-discuss  Start self-discussion: {\"topic\": \"...\", \"turns\": 3}",
            ]
        ])
    }

    // MARK: - Helpers

    nonisolated private static func parseJSON(_ body: String) -> [String: Any]? {
        guard let data = body.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    nonisolated private static func ok(_ extra: [String: Any] = [:]) -> String {
        var d: [String: Any] = ["status": "ok"]
        for (k, v) in extra { d[k] = v }
        return jsonDict(d)
    }

    nonisolated private static func err(_ message: String) -> String {
        jsonDict(["error": message])
    }

    nonisolated private static func jsonDict(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}

// MARK: - Socket helpers (nonisolated)

private func createListenerSocket(port: UInt16) -> Int32? {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    var opt: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = port.bigEndian
    addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian
    let bindResult = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
    }
    guard bindResult == 0, listen(fd, 5) == 0 else { close(fd); return nil }
    return fd
}

private func acceptSocket(_ listener: Int32) async throws -> Int32 {
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global().async {
            var clientAddr = sockaddr_in()
            var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            let client = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { accept(listener, $0, &len) }
            }
            client >= 0 ? continuation.resume(returning: client) : continuation.resume(throwing: NSError(domain: "accept", code: Int(client)))
        }
    }
}
