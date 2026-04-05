// ============================================================================
// ModelSettingsView.swift — Model parameters + connection settings
// Supports any OpenAI-compatible server, not just apfel.
// ============================================================================

import SwiftUI

struct ModelSettingsView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var tempEnabled: Bool = false
    @State private var tempValue: Double = 0.7
    @State private var maxTokEnabled: Bool = false
    @State private var maxTokValue: Int = 1024
    @State private var seedEnabled: Bool = false
    @State private var seedValue: Int = 0
    @State private var showAdvanced: Bool = false
    @State private var customHost: String = ""
    @State private var customPort: String = ""
    @State private var customModel: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.blue)
                Text("Model Settings")
                    .font(.headline)
                Spacer()
                if !viewModel.serverVersion.isEmpty {
                    Text("apfel \(viewModel.serverVersion)")
                        .font(.system(.caption2, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            // Temperature
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

            // Max Tokens
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

            // Seed
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

            // JSON Mode
            Toggle("JSON response mode", isOn: $viewModel.jsonMode)
                .toggleStyle(.checkbox)

            Divider()

            // Server info
            VStack(alignment: .leading, spacing: 6) {
                Text("Server Info")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                serverInfoRow("Context window", "\(viewModel.contextWindow) tokens")
                serverInfoRow("Model", viewModel.apiClient.modelName)
                serverInfoRow("Model available", viewModel.modelAvailable ? "Yes" : "No")
                serverInfoRow("Status", viewModel.serverStatus)
                serverInfoRow("Endpoint", viewModel.apiClient.baseURL.absoluteString)
                if !viewModel.supportedLanguages.isEmpty {
                    serverInfoRow("Languages", viewModel.supportedLanguages.joined(separator: ", "))
                }
            }
            .font(.caption)

            // Parameter capabilities
            if !viewModel.supportedParameters.isEmpty || !viewModel.unsupportedParameters.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Parameter Capabilities")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    if !viewModel.supportedParameters.isEmpty {
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption2)
                            Text(viewModel.supportedParameters.joined(separator: ", "))
                                .font(.system(.caption2, design: .monospaced))
                        }
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
                .font(.caption)
            }

            Divider()

            // Advanced: Connection Settings
            DisclosureGroup("Connection (Advanced)", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Point to any OpenAI-compatible API server.")
                        .font(.caption)
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
                        TextField("11438", text: $customPort)
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

                    Button("Apply Connection") {
                        applyConnection()
                    }
                    .font(.caption)
                }
                .padding(.top, 4)
            }
            .font(.caption)

            Divider()

            HStack {
                Button("Reset") {
                    tempEnabled = false
                    tempValue = 0.7
                    maxTokEnabled = false
                    maxTokValue = 1024
                    seedEnabled = false
                    seedValue = 0
                    viewModel.jsonMode = false
                    applyToViewModel()
                }
                Spacer()
                Button("Done") {
                    applyToViewModel()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            if let t = viewModel.temperature {
                tempEnabled = true
                tempValue = t
            }
            if let m = viewModel.maxTokens {
                maxTokEnabled = true
                maxTokValue = m
            }
            if let s = viewModel.seed {
                seedEnabled = true
                seedValue = s
            }
            // Load current connection
            let url = viewModel.apiClient.baseURL
            customHost = url.host() ?? "127.0.0.1"
            customPort = url.port.map(String.init) ?? "11438"
            customModel = viewModel.apiClient.modelName
        }
    }

    @ViewBuilder
    private func serverInfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private func applyToViewModel() {
        viewModel.temperature = tempEnabled ? tempValue : nil
        viewModel.maxTokens = maxTokEnabled ? maxTokValue : nil
        viewModel.seed = seedEnabled ? seedValue : nil
    }

    private func applyConnection() {
        let host = customHost.isEmpty ? "127.0.0.1" : customHost
        let port = customPort.isEmpty ? "11438" : customPort
        let model = customModel.isEmpty ? "apple-foundationmodel" : customModel

        if let url = URL(string: "http://\(host):\(port)") {
            viewModel.apiClient.baseURL = url
            viewModel.apiClient.modelName = model
            Task { await viewModel.fetchServerInfo() }
        }
    }
}
