// ============================================================================
// ChatView.swift — Main chat interface with message list and input field
// ============================================================================

import SwiftUI
import AppKit

enum FocusField {
    case messageInput
    case systemPrompt
}

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @FocusState private var focusedField: FocusField?
    private var visibleErrorMessage: String? {
        if let message = viewModel.stt.errorMessage, !message.isEmpty {
            return message
        }
        if let message = viewModel.errorMessage, !message.isEmpty {
            return message
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // System prompt — always visible, compact
            HStack(spacing: 8) {
                Text("System:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
                TextField("Optional system prompt", text: $viewModel.systemPrompt)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .focused($focusedField, equals: .systemPrompt)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.messages.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.messages) { msg in
                                MessageBubble(
                                    message: msg,
                                    isSelected: viewModel.selectedMessageId == msg.id,
                                    onSelect: {
                                        viewModel.selectedMessageId = msg.id
                                        viewModel.showDebugPanel = true
                                    },
                                    onSpeak: msg.role == "assistant" ? {
                                        viewModel.tts.speak(msg.content)
                                    } : nil
                                )
                                .id(msg.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.messages.last?.content) { _, _ in
                    scrollToBottom(proxy)
                }
            }

            Divider()

            // Error banner with typed error display
            if let errorMessage = visibleErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: errorIcon)
                        .foregroundStyle(errorColor)

                    VStack(alignment: .leading, spacing: 2) {
                        if let errorType = viewModel.errorType {
                            Text(APIClient.errorCategory(errorType))
                                .font(.caption.bold())
                                .foregroundStyle(errorColor)
                        }
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }

                    if viewModel.stt.shouldOfferOpenSettings {
                        Button("Open System Settings") {
                            viewModel.stt.openSystemSettings()
                        }
                        .font(.caption)
                    }
                    Spacer(minLength: 0)

                    Button(action: {
                        viewModel.errorMessage = nil
                        viewModel.errorType = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(errorBackgroundColor)

                Divider()
            }

            // Input bar
            HStack(alignment: .center, spacing: 8) {
                // Speaker toggle
                Button(action: { viewModel.speakEnabled.toggle() }) {
                    Image(systemName: viewModel.speakEnabled ? "speaker.wave.3.fill" : "speaker.slash")
                        .font(.body)
                        .foregroundColor(viewModel.speakEnabled ? .accentColor : .gray)
                }
                .buttonStyle(.borderless)
                .help(viewModel.speakEnabled ? "Speech on - click to mute" : "Speech off - click to enable")
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }

                // Microphone button
                Button(action: { viewModel.toggleListening() }) {
                    if viewModel.stt.isListening {
                        Label("Stop", systemImage: "stop.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .clipShape(Capsule())
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.body)
                            .foregroundColor(.gray)
                            .frame(width: 30, height: 30)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(.borderless)
                .help(viewModel.stt.isListening ? "Stop listening" : "Start voice input")
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }

                // Text input
                TextField(viewModel.stt.isListening ? "Listening..." : "Type a message, press Enter to send...", text: $viewModel.currentInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .focused($focusedField, equals: .messageInput)
                    .onSubmit {
                        Task { await viewModel.send() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusedField = .messageInput
                        }
                    }

                // Send button
                Button(action: {
                    Task { await viewModel.send() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        focusedField = .messageInput
                    }
                }) {
                    Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? .accentColor : Color(nsColor: .tertiaryLabelColor))
                }
                .buttonStyle(.borderless)
                .disabled(!canSend)

                Button(action: { viewModel.clear() }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.gray)
                        .frame(width: 30, height: 30)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                .help("Clear chat")
                .disabled(viewModel.messages.isEmpty && viewModel.currentInput.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = .messageInput
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("apfel")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            if !viewModel.serverVersion.isEmpty {
                Text("v\(viewModel.serverVersion) · \(viewModel.contextWindow)t context")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if !viewModel.mcpServerPaths.isEmpty {
                Text("\(viewModel.mcpServerPaths.count) MCP servers active")
                    .font(.caption)
                    .foregroundStyle(.purple.opacity(0.7))
            }
            Text("Press Enter to send")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var canSend: Bool {
        !viewModel.currentInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isStreaming
    }

    private var errorIcon: String {
        switch viewModel.errorType {
        case "content_policy_violation": return "shield.lefthalf.filled"
        case "context_length_exceeded": return "text.word.spacing"
        case "rate_limit_error": return "clock.arrow.2.circlepath"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private var errorColor: Color {
        switch viewModel.errorType {
        case "content_policy_violation": return .orange
        case "context_length_exceeded": return .purple
        case "rate_limit_error": return .blue
        default: return .yellow
        }
    }

    private var errorBackgroundColor: Color {
        switch viewModel.errorType {
        case "content_policy_violation": return Color.orange.opacity(0.05)
        case "rate_limit_error": return Color.blue.opacity(0.05)
        default: return Color(nsColor: .controlBackgroundColor)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let lastId = viewModel.messages.last?.id {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}
