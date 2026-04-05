// ============================================================================
// MainWindow.swift — Three-panel layout: Chat + Debug + Logs
// With server status bar and model settings
// ============================================================================

import SwiftUI

struct MainWindow: View {
    @Bindable var viewModel: ChatViewModel
    let apiClient: APIClient

    var body: some View {
        VStack(spacing: 0) {
            // Server status bar
            ServerStatusBar(viewModel: viewModel)

            // Main content: Chat + Debug sidebar
            HSplitView {
                ChatView(viewModel: viewModel)
                    .frame(minWidth: 350)

                DebugPanel(viewModel: viewModel)
                    .frame(minWidth: 280, idealWidth: 380, maxWidth: 500)
                    .opacity(viewModel.showDebugPanel ? 1 : 0)
                    .frame(width: viewModel.showDebugPanel ? nil : 0)
                    .clipped()
            }

            // Bottom: Log viewer (always rendered, visibility toggled)
            Divider()
                .opacity(viewModel.showLogPanel ? 1 : 0)
            LogViewer(apiClient: apiClient)
                .frame(height: viewModel.showLogPanel ? 200 : 0)
                .clipped()
                .opacity(viewModel.showLogPanel ? 1 : 0)
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: { viewModel.clear() }) {
                    Label("Clear", systemImage: "trash")
                }
                .keyboardShortcut("k", modifiers: .command)
                .help("Clear chat (Cmd+K)")

                Button(action: { viewModel.showSelfDiscussion = true }) {
                    Label("Self-Discuss", systemImage: "bubble.left.and.bubble.right")
                }
                .help("AI debates itself on a topic")
                .disabled(viewModel.isSelfDiscussing)

                Divider()

                Button(action: { viewModel.showModelSettings = true }) {
                    Label("Model", systemImage: "slider.horizontal.3")
                }
                .help("Model settings (temperature, max tokens, seed)")

                Button(action: { viewModel.showContextSettings = true }) {
                    Label("Context", systemImage: "gearshape")
                }
                .help("Context management settings")

                Toggle(isOn: $viewModel.showDebugPanel) {
                    Label("Debug", systemImage: "ant.circle")
                }
                .keyboardShortcut("d", modifiers: .command)
                .help("Toggle debug panel (Cmd+D)")

                Toggle(isOn: $viewModel.showLogPanel) {
                    Label("Logs", systemImage: "list.bullet.rectangle")
                }
                .keyboardShortcut("l", modifiers: .command)
                .help("Toggle log viewer (Cmd+L)")
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(isPresented: $viewModel.showSelfDiscussion) {
            SelfDiscussionView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showContextSettings) {
            ContextSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showModelSettings) {
            ModelSettingsView(viewModel: viewModel)
        }
    }
}

// MARK: - Server Status Bar

struct ServerStatusBar: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.modelAvailable ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text("apfel")
                    .fontWeight(.medium)
                if !viewModel.serverVersion.isEmpty {
                    Text("v\(viewModel.serverVersion)")
                        .foregroundStyle(.secondary)
                }
            }

            Divider().frame(height: 12)

            // Context window
            HStack(spacing: 3) {
                Image(systemName: "text.word.spacing")
                Text("\(viewModel.contextWindow)t context")
            }

            Divider().frame(height: 12)

            // Model settings summary
            HStack(spacing: 8) {
                if let t = viewModel.temperature {
                    badge("temp \(String(format: "%.1f", t))", color: .orange)
                }
                if let m = viewModel.maxTokens {
                    badge("max \(m)", color: .blue)
                }
                if let s = viewModel.seed {
                    badge("seed \(s)", color: .purple)
                }
                if viewModel.jsonMode {
                    badge("JSON", color: .green)
                }
                if viewModel.contextStrategy != .newestFirst {
                    badge(viewModel.contextStrategyRaw, color: .cyan)
                }
            }

            Spacer()

            // Active requests
            if viewModel.activeRequests > 0 {
                HStack(spacing: 3) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("\(viewModel.activeRequests) active")
                }
            }

            // Languages count
            if !viewModel.supportedLanguages.isEmpty {
                Text("\(viewModel.supportedLanguages.count) langs")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.system(.caption2, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    @ViewBuilder
    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .foregroundStyle(color)
    }
}
