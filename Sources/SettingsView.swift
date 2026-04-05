// ============================================================================
// SettingsView.swift - Unified tabbed settings for apfel-gui
// Consolidates: Model, Context, Speech, MCP, Connection
// ============================================================================

import SwiftUI
import AVFoundation
import AppKit

enum SettingsTab: String, CaseIterable {
    case model = "Model"
    case context = "Context"
    case speech = "Speech"
    case mcp = "MCP"
    case connection = "Connection"

    var icon: String {
        switch self {
        case .model: return "slider.horizontal.3"
        case .context: return "text.word.spacing"
        case .speech: return "speaker.wave.2"
        case .mcp: return "wrench.and.screwdriver"
        case .connection: return "network"
        }
    }
}

struct SettingsView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .model

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.body)
                            Text(tab.rawValue)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Divider()
                .padding(.top, 4)

            // Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .model: ModelTab(viewModel: viewModel)
                    case .context: ContextTab(viewModel: viewModel)
                    case .speech: SpeechTab(viewModel: viewModel)
                    case .mcp: MCPTab(viewModel: viewModel)
                    case .connection: ConnectionTab(viewModel: viewModel)
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                if !viewModel.serverVersion.isEmpty {
                    Text("apfel v\(viewModel.serverVersion)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 480, height: 420)
    }
}

// MARK: - Model Tab

private struct ModelTab: View {
    @Bindable var viewModel: ChatViewModel

    @State private var tempEnabled: Bool = false
    @State private var tempValue: Double = 0.7
    @State private var maxTokEnabled: Bool = false
    @State private var maxTokValue: Int = 1024
    @State private var seedEnabled: Bool = false
    @State private var seedValue: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Generation Parameters")

            HStack {
                Toggle("Temperature", isOn: $tempEnabled)
                    .toggleStyle(.checkbox)
                Spacer()
                if tempEnabled {
                    Text(String(format: "%.1f", tempValue))
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 30)
                    Slider(value: $tempValue, in: 0...2, step: 0.1)
                        .frame(width: 150)
                }
            }

            HStack {
                Toggle("Max tokens", isOn: $maxTokEnabled)
                    .toggleStyle(.checkbox)
                Spacer()
                if maxTokEnabled {
                    TextField("", value: $maxTokValue, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                }
            }

            HStack {
                Toggle("Seed", isOn: $seedEnabled)
                    .toggleStyle(.checkbox)
                Spacer()
                if seedEnabled {
                    TextField("", value: $seedValue, format: .number)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                }
            }

            Toggle("JSON response mode", isOn: $viewModel.jsonMode)
                .toggleStyle(.checkbox)

            // Parameter capabilities
            if !viewModel.supportedParameters.isEmpty {
                Divider()
                sectionHeader("Supported Parameters")
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption2)
                    Text(viewModel.supportedParameters.joined(separator: ", "))
                        .font(.system(.caption2, design: .monospaced))
                }
                if !viewModel.unsupportedParameters.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption2)
                        Text(viewModel.unsupportedParameters.joined(separator: ", "))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
            Button("Reset") {
                tempEnabled = false; tempValue = 0.7
                maxTokEnabled = false; maxTokValue = 1024
                seedEnabled = false; seedValue = 0
                viewModel.jsonMode = false
                applyToViewModel()
            }
            .font(.caption)
        }
        .font(.caption)
        .onAppear {
            if let t = viewModel.temperature { tempEnabled = true; tempValue = t }
            if let m = viewModel.maxTokens { maxTokEnabled = true; maxTokValue = m }
            if let s = viewModel.seed { seedEnabled = true; seedValue = s }
        }
        .onDisappear { applyToViewModel() }
    }

    private func applyToViewModel() {
        viewModel.temperature = tempEnabled ? tempValue : nil
        viewModel.maxTokens = maxTokEnabled ? maxTokValue : nil
        viewModel.seed = seedEnabled ? seedValue : nil
    }
}

// MARK: - Context Tab

private struct ContextTab: View {
    @Bindable var viewModel: ChatViewModel

    private var currentStrategy: ContextStrategy {
        ContextStrategy(rawValue: viewModel.contextStrategyRaw) ?? .newestFirst
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Context Management")

            Picker("Strategy", selection: $viewModel.contextStrategyRaw) {
                ForEach(ContextStrategy.allCases, id: \.rawValue) { strategy in
                    Text(strategy.rawValue).tag(strategy.rawValue)
                }
            }
            .pickerStyle(.menu)

            strategyDescription

            if currentStrategy == .slidingWindow {
                HStack {
                    Text("Max turns:")
                    TextField("e.g. 6", value: $viewModel.contextMaxTurns, format: .number)
                        .frame(width: 60)
                }
            }

            HStack {
                Text("Output reserve:")
                Stepper(
                    "\(viewModel.contextOutputReserve) tokens",
                    value: $viewModel.contextOutputReserve,
                    in: 128...2048, step: 128
                )
            }

            // Server info
            Divider()
            sectionHeader("Context Window")
            HStack {
                Text("Size:")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.contextWindow) tokens")
                    .font(.system(.caption, design: .monospaced))
            }

            Spacer()
            Button("Reset") {
                viewModel.contextStrategyRaw = ContextStrategy.newestFirst.rawValue
                viewModel.contextMaxTurns = nil
                viewModel.contextOutputReserve = 512
            }
            .font(.caption)
        }
        .font(.caption)
    }

    @ViewBuilder
    private var strategyDescription: some View {
        let desc: String = switch currentStrategy {
        case .newestFirst: "Keeps the most recent turns that fit within the context window."
        case .oldestFirst: "Keeps the oldest turns. Good for reference-heavy conversations."
        case .slidingWindow: "Keeps the last N turns, then enforces the token budget."
        case .summarize: "Compresses old turns into a summary using the on-device model."
        case .strict: "No trimming. Returns an error if context is exceeded."
        }
        Text(desc)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Speech Tab

private struct SpeechTab: View {
    @Bindable var viewModel: ChatViewModel
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var previewText = "Hello, I am Apple Intelligence."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Text-to-Speech")

            Toggle("Enable speech", isOn: $viewModel.speakEnabled)
                .toggleStyle(.checkbox)

            // Language picker
            Picker("Language", selection: $viewModel.speechLanguage) {
                ForEach(TTSManager.preferredVoices) { voice in
                    Text(voice.label).tag(voice.languageCode)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.speechLanguage) { _, _ in
                loadVoices()
                viewModel.selectedVoiceId = nil // reset to auto
            }

            // Voice picker - all on-device voices for selected language
            Divider()
            sectionHeader("Voice (\(availableVoices.count) installed)")

            Picker("Voice", selection: $viewModel.selectedVoiceId) {
                Text("Auto (best available)").tag(nil as String?)
                ForEach(availableVoices, id: \.identifier) { voice in
                    Text("\(voice.name) - \(voiceQualityLabel(voice))")
                        .tag(voice.identifier as String?)
                }
            }
            .pickerStyle(.menu)

            // Preview
            HStack {
                TextField("Preview text", text: $previewText)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                Button("Play") {
                    let voiceId = viewModel.selectedVoiceId
                    viewModel.tts.speak(previewText, languageCode: viewModel.speechLanguage, voiceId: voiceId)
                }
                .font(.caption)
                Button("Stop") {
                    viewModel.tts.stop()
                }
                .font(.caption)
            }

            // Voice info
            if let selectedId = viewModel.selectedVoiceId,
               let voice = availableVoices.first(where: { $0.identifier == selectedId }) {
                Divider()
                sectionHeader("Selected Voice")
                voiceInfoRow("Name", voice.name)
                voiceInfoRow("Language", voice.language)
                voiceInfoRow("Quality", voiceQualityLabel(voice))
                voiceInfoRow("Identifier", voice.identifier)
            }

            Divider()
            Text("Download more voices: System Settings > Accessibility > Read & Speak > System voice")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .font(.caption)
        .onAppear { loadVoices() }
    }

    private func loadVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == viewModel.speechLanguage }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality { return lhs.quality.rawValue > rhs.quality.rawValue }
                let lhsSiri = lhs.identifier.lowercased().contains("siri")
                let rhsSiri = rhs.identifier.lowercased().contains("siri")
                if lhsSiri != rhsSiri { return lhsSiri }
                return lhs.name < rhs.name
            }
    }

    private func voiceQualityLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        default:
            if voice.identifier.lowercased().contains("siri") { return "Siri" }
            if voice.identifier.contains("com.apple.speech.synthesis.voice.") { return "Novelty" }
            if voice.identifier.contains("eloquence") { return "Eloquence" }
            return "Default"
        }
    }

    @ViewBuilder
    private func voiceInfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

// MARK: - MCP Tab

private struct MCPTab: View {
    @Bindable var viewModel: ChatViewModel
    @State private var newPath: String = ""
    @State private var userPaths: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("MCP Tool Servers")

            Text("apfel auto-injects MCP tools into chat completions. Tool calls and results are visible in the Debug Inspector.")
                .foregroundStyle(.secondary)

            // Active servers
            if viewModel.mcpServerPaths.isEmpty {
                Text("No MCP servers active")
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(Array(viewModel.mcpServerPaths.enumerated()), id: \.offset) { _, path in
                    HStack(spacing: 6) {
                        Image(systemName: serverIcon(path))
                            .foregroundStyle(serverColor(path))
                            .frame(width: 14)
                        Text(serverLabel(path))
                            .fontWeight(.medium)
                        Spacer()
                        Text(path.components(separatedBy: "/").suffix(3).joined(separator: "/"))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }
            }

            Divider()
            sectionHeader("Add Custom Server")

            HStack {
                TextField("Path to .py or executable", text: $newPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                Button("Browse") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK, let url = panel.url {
                        newPath = url.path
                    }
                }
                Button("+") { addServer() }
                    .disabled(newPath.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !userPaths.isEmpty {
                ForEach(Array(userPaths.enumerated()), id: \.offset) { idx, path in
                    HStack {
                        Text(path)
                            .font(.system(.caption2, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button(action: { removeServer(at: idx) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Text("Changes require restarting apfel-gui.")
                .foregroundStyle(.tertiary)
                .font(.caption2)

            Spacer()
        }
        .font(.caption)
        .onAppear {
            userPaths = UserDefaults.standard.stringArray(forKey: "mcpServerPaths") ?? []
        }
    }

    private func addServer() {
        let path = newPath.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return }
        userPaths.append(path)
        UserDefaults.standard.set(userPaths, forKey: "mcpServerPaths")
        newPath = ""
    }

    private func removeServer(at index: Int) {
        userPaths.remove(at: index)
        UserDefaults.standard.set(userPaths, forKey: "mcpServerPaths")
    }

    private func serverLabel(_ path: String) -> String {
        if path.contains("debug-tools") { return "Debug Tools (bundled)" }
        if path.contains("calculator") { return "Calculator (apfel)" }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func serverIcon(_ path: String) -> String {
        if path.contains("debug-tools") { return "ladybug.fill" }
        if path.contains("calculator") { return "function" }
        return "gear"
    }

    private func serverColor(_ path: String) -> Color {
        if path.contains("debug-tools") { return .purple }
        if path.contains("calculator") { return .orange }
        return .blue
    }
}

// MARK: - Connection Tab

private struct ConnectionTab: View {
    @Bindable var viewModel: ChatViewModel
    @State private var customHost: String = ""
    @State private var customPort: String = ""
    @State private var customModel: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Server Connection")

            Text("Point to any OpenAI-compatible API server.")
                .foregroundStyle(.secondary)

            HStack {
                Text("Host:")
                    .frame(width: 50, alignment: .trailing)
                TextField("127.0.0.1", text: $customHost)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }

            HStack {
                Text("Port:")
                    .frame(width: 50, alignment: .trailing)
                TextField("\(apfelGUIPort)", text: $customPort)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 80)
                Spacer()
            }

            HStack {
                Text("Model:")
                    .frame(width: 50, alignment: .trailing)
                TextField("apple-foundationmodel", text: $customModel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
            }

            Button("Apply") { applyConnection() }

            Divider()
            sectionHeader("Server Info")
            infoRow("Status", viewModel.serverStatus)
            infoRow("Model", viewModel.apiClient.modelName)
            infoRow("Available", viewModel.modelAvailable ? "Yes" : "No")
            infoRow("Endpoint", viewModel.apiClient.baseURL.absoluteString)
            if !viewModel.supportedLanguages.isEmpty {
                infoRow("Languages", "\(viewModel.supportedLanguages.count) supported")
            }

            Spacer()
        }
        .font(.caption)
        .onAppear {
            let url = viewModel.apiClient.baseURL
            customHost = url.host() ?? "127.0.0.1"
            customPort = url.port.map(String.init) ?? "\(apfelGUIPort)"
            customModel = viewModel.apiClient.modelName
        }
    }

    private func applyConnection() {
        let host = customHost.isEmpty ? "127.0.0.1" : customHost
        let port = customPort.isEmpty ? "\(apfelGUIPort)" : customPort
        let model = customModel.isEmpty ? "apple-foundationmodel" : customModel
        if let url = URL(string: "http://\(host):\(port)") {
            viewModel.apiClient.baseURL = url
            viewModel.apiClient.modelName = model
            Task { await viewModel.fetchServerInfo() }
        }
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

// MARK: - Shared Helpers

private func sectionHeader(_ title: String) -> some View {
    Text(title)
        .font(.caption.bold())
        .foregroundStyle(.secondary)
}
