// ============================================================================
// DebugPanel.swift — Request/response JSON viewer with copy buttons
// The truthful debug inspector — shows everything, hides nothing.
// ============================================================================

import SwiftUI
import AppKit

struct DebugPanel: View {
    @Bindable var viewModel: ChatViewModel

    private var strategyLabel: String { viewModel.contextStrategyRaw }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "ant.circle.fill")
                    .foregroundStyle(.orange)
                Text("Debug Inspector")
                    .font(.headline)
                Spacer()
                Toggle("Auto-follow", isOn: $viewModel.debugAutoFollow)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                if viewModel.selectedMessage != nil {
                    Button("Clear") {
                        viewModel.selectedMessageId = nil
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if let msg = viewModel.selectedMessage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // =============================================
                        // 1. WHAT WE SENT (the request)
                        // =============================================

                        if let json = msg.requestJSON {
                            codeSection(
                                title: "1. Request (HTTP Body)",
                                icon: "arrow.up.doc.fill",
                                text: json,
                                color: .orange
                            )
                        }

                        // =============================================
                        // 2. SERVER PROCESSING (what happened inside apfel)
                        // =============================================

                        // Server trace (chronological events)
                        if let events = msg.serverEvents, !events.isEmpty {
                            infoCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                                            .foregroundStyle(.cyan)
                                        Text("2. Server Processing")
                                            .font(.caption.bold())
                                        Spacer()
                                        if let reqId = msg.serverRequestId {
                                            Text(reqId)
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                                        HStack(alignment: .top, spacing: 6) {
                                            Text("\(idx + 1)")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundStyle(.quaternary)
                                                .frame(width: 16, alignment: .trailing)
                                            Circle()
                                                .fill(eventColor(event))
                                                .frame(width: 6, height: 6)
                                                .padding(.top, 4)
                                            Text(event)
                                                .font(.system(.caption2, design: .monospaced))
                                                .textSelection(.enabled)
                                        }
                                    }
                                }
                            }
                        }

                        // =============================================
                        // 3. MCP TOOL CALLS (if any)
                        // =============================================

                        if let events = msg.serverEvents {
                            let mcpToolEvents = events.filter { $0.hasPrefix("mcp tool:") }
                            if !mcpToolEvents.isEmpty {
                                ForEach(Array(mcpToolEvents.enumerated()), id: \.offset) { _, event in
                                    let detail = String(event.dropFirst(10))
                                    let parsed = parseMCPToolEvent(detail)

                                    codeSection(
                                        title: "3a. MCP Request (JSON-RPC tools/call)",
                                        icon: "arrow.up.doc.fill",
                                        text: parsed.requestJSON,
                                        color: .purple
                                    )

                                    codeSection(
                                        title: "3b. MCP Response (JSON-RPC result)",
                                        icon: "arrow.down.doc.fill",
                                        text: parsed.responseJSON,
                                        color: .green
                                    )
                                }
                            }
                        }

                        // =============================================
                        // 4. RESPONSE (what came back)
                        // =============================================

                        // Summary card
                        infoCard {
                            HStack {
                                Label(msg.role == "user" ? "User Message" : "4. Response",
                                      systemImage: msg.role == "user" ? "person.circle" : "cpu")
                                Spacer()
                                if let ms = msg.durationMs {
                                    pill("\(ms)ms", color: .green)
                                }
                                if let tokens = msg.tokenCount {
                                    pill("\(tokens) tokens", color: .blue)
                                }
                                if let reason = msg.finishReason {
                                    pill(reason, color: finishReasonColor(reason))
                                }
                            }
                            .font(.caption)

                            if msg.promptTokens != nil || msg.completionTokens != nil {
                                HStack(spacing: 12) {
                                    if let pt = msg.promptTokens {
                                        HStack(spacing: 3) {
                                            Image(systemName: "arrow.up")
                                                .foregroundStyle(.orange)
                                            Text("\(pt) prompt")
                                        }
                                    }
                                    if let ct = msg.completionTokens {
                                        HStack(spacing: 3) {
                                            Image(systemName: "arrow.down")
                                                .foregroundStyle(.green)
                                            Text("\(ct) completion")
                                        }
                                    }
                                }
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                            }
                        }

                        // Error type
                        if let errorType = msg.errorType {
                            infoCard {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.red)
                                    Text(APIClient.errorCategory(errorType))
                                        .font(.caption.bold())
                                        .foregroundStyle(.red)
                                    Spacer()
                                    Text(errorType)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Context budget
                        if let tokens = msg.tokenCount {
                            let ctxWindow = viewModel.contextWindow
                            let ratio = min(1.0, Double(tokens) / Double(ctxWindow))
                            let color: Color = ratio < 0.5 ? .green : ratio < 0.8 ? .yellow : .red
                            infoCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "gauge.with.dots.needle.33percent")
                                        Text("Context Budget")
                                            .font(.caption.bold())
                                        Spacer()
                                        Text("\(tokens) / \(ctxWindow) tokens")
                                            .font(.system(.caption, design: .monospaced))
                                    }
                                    ProgressView(value: ratio)
                                        .tint(color)
                                    HStack {
                                        Image(systemName: "arrow.triangle.branch")
                                        Text("Strategy: \(strategyLabel)")
                                            .font(.system(.caption, design: .monospaced))
                                        Spacer()
                                        Text("\(Int(ratio * 100))% used")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(color)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Raw SSE response
                        if let json = msg.responseJSON {
                            codeSection(
                                title: "Raw Server Response (SSE)",
                                icon: "arrow.down.doc.fill",
                                text: json,
                                color: .green
                            )
                        }

                        // =============================================
                        // 5. REPRODUCE (copy-paste commands)
                        // =============================================

                        if let curl = msg.curlCommand {
                            codeSection(
                                title: "5a. curl Command",
                                icon: "terminal",
                                text: curl,
                                color: .blue
                            )
                        }

                        if msg.role == "user" || msg.role == "assistant" {
                            let cliCmd = buildApfelCLICommand(for: msg)
                            if !cliCmd.isEmpty {
                                codeSection(
                                    title: "5b. Equivalent apfel CLI",
                                    icon: "terminal.fill",
                                    text: cliCmd,
                                    color: .orange
                                )
                            }
                        }

                        if !viewModel.serverLaunchCommand.isEmpty {
                            codeSection(
                                title: "5c. Server Launch Command",
                                icon: "power",
                                text: viewModel.serverLaunchCommand,
                                color: .cyan
                            )
                        }
                    }
                    .padding(12)
                }
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "ant.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No message selected")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                    Text("Click the \(Image(systemName: "ant.circle")) Inspect button\nnext to any message")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - CLI Command Builder

    /// Build an equivalent `apfel` CLI command for the given message.
    private func buildApfelCLICommand(for msg: ChatMsg) -> String {
        // Find the user message content (either this message or the one before it)
        let userContent: String
        if msg.role == "user" {
            userContent = msg.content
        } else if let idx = viewModel.messages.firstIndex(where: { $0.id == msg.id }),
                  idx > 0, viewModel.messages[idx - 1].role == "user" {
            userContent = viewModel.messages[idx - 1].content
        } else {
            return ""
        }

        var parts = ["apfel"]

        // System prompt
        if !viewModel.systemPrompt.isEmpty {
            parts.append("-s \"\(viewModel.systemPrompt.replacingOccurrences(of: "\"", with: "\\\""))\"")
        }

        // Model settings
        if let t = viewModel.temperature {
            parts.append("--temperature \(String(format: "%.1f", t))")
        }
        if let m = viewModel.maxTokens {
            parts.append("--max-tokens \(m)")
        }
        if let s = viewModel.seed {
            parts.append("--seed \(s)")
        }

        // Context strategy
        let strategy = viewModel.contextStrategy
        if strategy != .newestFirst {
            parts.append("--context-strategy \(strategy.rawValue)")
        }
        if let maxTurns = viewModel.contextMaxTurns {
            parts.append("--context-max-turns \(maxTurns)")
        }
        if viewModel.contextOutputReserve != 512 {
            parts.append("--context-output-reserve \(viewModel.contextOutputReserve)")
        }

        // MCP servers
        for path in viewModel.mcpServerPaths {
            parts.append("--mcp \(path)")
        }

        // JSON mode
        if viewModel.jsonMode {
            parts.append("-o json")
        }

        // The prompt
        parts.append("\"\(userContent.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n"))\"")

        return parts.joined(separator: " \\\n  ")
    }

    // MARK: - MCP JSON-RPC Reconstruction

    private struct MCPToolParsed {
        let requestJSON: String
        let responseJSON: String
    }

    /// Reconstruct full JSON-RPC request/response from server event string.
    /// Input: "multiply({"a": 247, "b": 83}) = 20501"
    private func parseMCPToolEvent(_ detail: String) -> MCPToolParsed {
        // Parse: "functionName(arguments) = result"
        guard let parenIdx = detail.firstIndex(of: "("),
              let eqRange = detail.range(of: ") = ") else {
            return MCPToolParsed(
                requestJSON: "{\n  \"jsonrpc\": \"2.0\",\n  \"method\": \"tools/call\",\n  \"params\": \"\(detail)\"\n}",
                responseJSON: "{}"
            )
        }

        let name = String(detail[detail.startIndex..<parenIdx])
        let argsStart = detail.index(after: parenIdx)
        let argsRaw = String(detail[argsStart..<eqRange.lowerBound])
        let result = String(detail[eqRange.upperBound...])

        // Pretty-print the arguments JSON
        let prettyArgs: String
        if let data = argsRaw.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            prettyArgs = str
        } else {
            prettyArgs = argsRaw
        }

        let requestJSON = """
        {
          "jsonrpc": "2.0",
          "method": "tools/call",
          "params": {
            "name": "\(name)",
            "arguments": \(prettyArgs)
          }
        }
        """

        let responseJSON = """
        {
          "jsonrpc": "2.0",
          "result": {
            "content": [
              {
                "type": "text",
                "text": "\(result.replacingOccurrences(of: "\"", with: "\\\""))"
              }
            ],
            "isError": false
          }
        }
        """

        return MCPToolParsed(requestJSON: requestJSON, responseJSON: responseJSON)
    }

    // MARK: - Components

    @ViewBuilder
    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func infoCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func codeSection(title: String, icon: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                CopyButton(text: text)
            }
            .font(.caption)

            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        }
    }

    private func eventColor(_ event: String) -> Color {
        if event.contains("error") || event.contains("fail") { return .red }
        if event.contains("context built") { return .blue }
        if event.contains("chunk") || event.contains("delta") { return .green }
        if event.contains("tool") { return .purple }
        if event.contains("stream") || event.contains("SSE") || event.contains("[DONE]") { return .orange }
        if event.contains("finish_reason") || event.contains("sent [DONE]") { return .cyan }
        if event.contains("request") || event.contains("decoded") { return .secondary }
        return .secondary
    }

    private func finishReasonColor(_ reason: String) -> Color {
        switch reason {
        case "stop": return .green
        case "tool_calls": return .purple
        case "length": return .yellow
        case "content_filter": return .red
        default: return .secondary
        }
    }
}

// MARK: - Copy Button with Hover + Click Feedback

struct CopyButton: View {
    let text: String
    @State private var isHovered = false
    @State private var justCopied = false

    var body: some View {
        Button(action: {
            if copyToPasteboard(text) {
                justCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    justCopied = false
                }
            } else {
                NSSound.beep()
            }
        }) {
            Label(justCopied ? "Copied!" : "Copy", systemImage: justCopied ? "checkmark.circle.fill" : "doc.on.doc")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    isHovered
                        ? Color(nsColor: .controlBackgroundColor)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .foregroundColor(justCopied ? .green : .secondary)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    @MainActor
    private func copyToPasteboard(_ value: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.prepareForNewContents(with: .currentHostOnly)
        guard pasteboard.setString(value, forType: .string) else { return false }
        return pasteboard.string(forType: .string) == value
    }
}
