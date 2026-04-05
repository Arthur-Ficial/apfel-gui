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
                        // Message info
                        infoCard {
                            HStack {
                                Label(msg.role == "user" ? "User Message" : "AI Response",
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

                            // Detailed token breakdown
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

                        // Error type badge
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

                        // Token budget bar
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

                        // Tool calls
                        if let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
                            infoCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "wrench.and.screwdriver")
                                            .foregroundStyle(.purple)
                                        Text("Tool Calls (\(toolCalls.count))")
                                            .font(.caption.bold())
                                    }
                                    ForEach(Array(toolCalls.enumerated()), id: \.offset) { _, tc in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(tc.functionName)
                                                    .font(.system(.caption, design: .monospaced))
                                                    .fontWeight(.semibold)
                                                Spacer()
                                                CopyButton(text: tc.arguments)
                                            }
                                            Text(tc.arguments)
                                                .font(.system(.caption2, design: .monospaced))
                                                .textSelection(.enabled)
                                                .padding(6)
                                                .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                    }
                                }
                            }
                        }

                        // MCP Tool Execution - Full JSON-RPC request/response
                        if let events = msg.serverEvents {
                            let mcpToolEvents = events.filter { $0.hasPrefix("mcp tool:") }
                            let mcpOtherEvents = events.filter { ($0.hasPrefix("mcp ") || $0.hasPrefix("mcp:")) && !$0.hasPrefix("mcp tool:") }
                            if !mcpToolEvents.isEmpty {
                                // Show full JSON-RPC for each tool call
                                ForEach(Array(mcpToolEvents.enumerated()), id: \.offset) { _, event in
                                    let detail = String(event.dropFirst(10)) // drop "mcp tool: "
                                    let parsed = parseMCPToolEvent(detail)

                                    // MCP JSON-RPC Request
                                    codeSection(
                                        title: "MCP Request (JSON-RPC tools/call)",
                                        icon: "arrow.up.doc.fill",
                                        text: parsed.requestJSON,
                                        color: .purple
                                    )

                                    // MCP JSON-RPC Response
                                    codeSection(
                                        title: "MCP Response (JSON-RPC result)",
                                        icon: "arrow.down.doc.fill",
                                        text: parsed.responseJSON,
                                        color: .green
                                    )
                                }
                            }
                            if !mcpOtherEvents.isEmpty {
                                infoCard {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: "wrench.and.screwdriver")
                                                .foregroundStyle(.purple)
                                            Text("MCP Events")
                                                .font(.caption.bold())
                                            Spacer()
                                        }
                                        ForEach(Array(mcpOtherEvents.enumerated()), id: \.offset) { _, event in
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(Color.purple.opacity(0.6))
                                                    .frame(width: 5, height: 5)
                                                Text(event)
                                                    .font(.system(.caption2, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Server-side event trace
                        if let events = msg.serverEvents, !events.isEmpty {
                            infoCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                                            .foregroundStyle(.cyan)
                                        Text("Server Trace")
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

                        // curl command
                        if let curl = msg.curlCommand {
                            codeSection(
                                title: "curl Command (copy & paste to reproduce)",
                                icon: "terminal",
                                text: curl,
                                color: .purple
                            )
                        }

                        // What we SENT to the server
                        if let json = msg.requestJSON {
                            codeSection(
                                title: "What We Sent (HTTP Request Body)",
                                icon: "arrow.up.doc.fill",
                                text: json,
                                color: .orange
                            )
                        }

                        // What the server RESPONDED with (raw, truthful)
                        if let json = msg.responseJSON {
                            codeSection(
                                title: "What We Got Back (Raw Server Response)",
                                icon: "arrow.down.doc.fill",
                                text: json,
                                color: .green
                            )
                        }

                        // Extracted content
                        codeSection(
                            title: "Extracted Content",
                            icon: "text.quote",
                            text: msg.content,
                            color: .primary
                        )
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
