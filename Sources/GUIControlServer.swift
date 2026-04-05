// ============================================================================
// GUIControlServer.swift - HTTP API for programmatic GUI control
// Enables automated testing without clicking. Runs on port 11439.
// ============================================================================

import Foundation
import AVFoundation

/// Lightweight HTTP server for controlling the GUI programmatically.
/// Used for automated testing - send messages, change settings, query state.
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
                printStderr("GUI control: failed to start on port \(p)")
                return
            }
            printStderr("GUI control: http://127.0.0.1:\(p)")

            while true {
                guard let client = try? await Self.acceptConnection(listener) else { continue }
                Task.detached {
                    await Self.handleConnection(client, viewModel: vm)
                }
            }
        }
    }

    // MARK: - Socket Helpers

    nonisolated private static func acceptConnection(_ listener: Int32) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                var clientAddr = sockaddr_in()
                var len = socklen_t(MemoryLayout<sockaddr_in>.size)
                let client = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { accept(listener, $0, &len) }
                }
                if client >= 0 {
                    continuation.resume(returning: client)
                } else {
                    continuation.resume(throwing: NSError(domain: "accept", code: Int(client)))
                }
            }
        }
    }

    private static func handleConnection(_ client: Int32, viewModel: ChatViewModel) async {
        // Read request
        var buffer = [UInt8](repeating: 0, count: 8192)
        let n = read(client, &buffer, buffer.count)
        guard n > 0 else { close(client); return }
        let request = String(bytes: buffer[0..<n], encoding: .utf8) ?? ""

        // Parse method + path
        let firstLine = request.split(separator: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { close(client); return }
        let method = String(parts[0])
        let path = String(parts[1])

        // Parse body for POST
        let body: String
        if let bodyStart = request.range(of: "\r\n\r\n") {
            body = String(request[bodyStart.upperBound...])
        } else {
            body = ""
        }

        // Route
        let response: String
        switch (method, path) {
        case ("GET", "/state"):
            response = await getState(viewModel)
        case ("POST", "/send"):
            response = await sendMessage(body, viewModel: viewModel)
        case ("POST", "/settings"):
            response = await updateSettings(body, viewModel: viewModel)
        case ("POST", "/clear"):
            await MainActor.run { viewModel.clear() }
            response = json(["status": "ok"])
        case ("GET", "/voices"):
            response = getVoices(viewModel)
        case ("POST", "/speak"):
            response = await speak(body, viewModel: viewModel)
        default:
            response = json(["error": "Unknown: \(method) \(path)", "routes": [
                "GET /state", "POST /send", "POST /settings", "POST /clear",
                "GET /voices", "POST /speak"
            ]])
        }

        // Send HTTP response
        let http = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: \(response.utf8.count)\r\n\r\n\(response)"
        _ = http.withCString { write(client, $0, Int(strlen($0))) }
        close(client)
    }

    // MARK: - Handlers

    private static func getState(_ vm: ChatViewModel) async -> String {
        await MainActor.run {
            let msgs = vm.messages.map { msg -> [String: Any] in
                var m: [String: Any] = ["id": msg.id, "role": msg.role, "content": msg.content]
                if let ms = msg.durationMs { m["duration_ms"] = ms }
                if let tokens = msg.tokenCount { m["tokens"] = tokens }
                if let reason = msg.finishReason { m["finish_reason"] = reason }
                return m
            }
            let state: [String: Any] = [
                "messages": msgs,
                "is_streaming": vm.isStreaming,
                "speech_language": vm.speechLanguage,
                "speech_enabled": vm.speakEnabled,
                "selected_voice_id": vm.selectedVoiceId ?? "auto",
                "mcp_servers": vm.mcpServerPaths,
                "server_version": vm.serverVersion,
                "context_window": vm.contextWindow,
                "model_available": vm.modelAvailable,
            ]
            return jsonDict(state)
        }
    }

    private static func sendMessage(_ body: String, viewModel vm: ChatViewModel) async -> String {
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = obj["message"] as? String else {
            return json(["error": "Need {\"message\": \"text\"}"])
        }
        await MainActor.run {
            vm.currentInput = message
        }
        await vm.send()
        // Return the last assistant message
        let lastMsg = await MainActor.run { vm.messages.last }
        if let msg = lastMsg {
            return json(["status": "ok", "role": msg.role, "content": msg.content,
                         "finish_reason": msg.finishReason ?? "unknown",
                         "tokens": msg.tokenCount ?? 0,
                         "duration_ms": msg.durationMs ?? 0])
        }
        return json(["status": "ok"])
    }

    private static func updateSettings(_ body: String, viewModel vm: ChatViewModel) async -> String {
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return json(["error": "Invalid JSON"])
        }
        await MainActor.run {
            if let lang = obj["speech_language"] as? String { vm.speechLanguage = lang }
            if let voiceId = obj["voice_id"] as? String { vm.selectedVoiceId = voiceId == "auto" ? nil : voiceId }
            if let speak = obj["speak_enabled"] as? Bool { vm.speakEnabled = speak }
            if let temp = obj["temperature"] as? Double { vm.temperature = temp }
            if let maxTok = obj["max_tokens"] as? Int { vm.maxTokens = maxTok }
            if let seed = obj["seed"] as? Int { vm.seed = seed }
            if let jsonMode = obj["json_mode"] as? Bool { vm.jsonMode = jsonMode }
            if let strategy = obj["context_strategy"] as? String { vm.contextStrategyRaw = strategy }
        }
        return json(["status": "ok"])
    }

    private static func getVoices(_ vm: ChatViewModel) -> String {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let grouped = Dictionary(grouping: voices) { $0.language }
        var result: [[String: Any]] = []
        for (lang, vs) in grouped.sorted(by: { $0.key < $1.key }) {
            for v in vs.sorted(by: { $0.quality.rawValue > $1.quality.rawValue }) {
                result.append([
                    "name": v.name,
                    "language": v.language,
                    "quality": v.quality.rawValue,
                    "identifier": v.identifier,
                ])
            }
        }
        return jsonDict(["voices": result, "count": result.count, "current_language": vm.speechLanguage])
    }

    private static func speak(_ body: String, viewModel vm: ChatViewModel) async -> String {
        guard let data = body.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = obj["text"] as? String else {
            return json(["error": "Need {\"text\": \"...\"}"])
        }
        let voiceId = obj["voice_id"] as? String
        let lang = obj["language"] as? String
        await MainActor.run {
            vm.tts.speak(text, languageCode: lang ?? vm.speechLanguage, voiceId: voiceId ?? vm.selectedVoiceId)
        }
        return json(["status": "speaking", "text": text])
    }

    // MARK: - JSON Helpers

    private static func json(_ dict: [String: Any]) -> String {
        jsonDict(dict)
    }

    private static func jsonDict(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}

// MARK: - Free function (nonisolated)

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
