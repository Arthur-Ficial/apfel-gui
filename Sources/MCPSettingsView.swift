// ============================================================================
// MCPSettingsView.swift — MCP tool server configuration
// Shows which MCP servers are enabled + lets users add custom ones.
// apfel handles all MCP logic — the GUI just configures and visualizes.
// ============================================================================

import SwiftUI
import AppKit

struct MCPSettingsView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newPath: String = ""
    @State private var userPaths: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(.purple)
                Text("MCP Tool Servers")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.mcpServerPaths.count) active")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text("apfel auto-injects MCP tools into chat completions. The model sees these tools and can call them. Tool calls and server events are visible in the Debug Inspector.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Active MCP servers
            Text("Active Servers")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if viewModel.mcpServerPaths.isEmpty {
                Text("No MCP servers configured")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(viewModel.mcpServerPaths.enumerated()), id: \.offset) { _, path in
                    HStack(spacing: 8) {
                        Image(systemName: serverIcon(path))
                            .foregroundStyle(serverColor(path))
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(serverLabel(path))
                                .font(.caption.bold())
                            Text(path)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Text(serverBadge(path))
                            .font(.system(.caption2, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(serverColor(path).opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(serverColor(path))
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider()

            // Add custom MCP server
            Text("Add Custom Server")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack {
                TextField("Path to MCP server (.py or executable)", text: $newPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))

                Button("Browse...") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.allowedContentTypes = [.pythonScript, .unixExecutable, .item]
                    if panel.runModal() == .OK, let url = panel.url {
                        newPath = url.path
                    }
                }
                .font(.caption)

                Button(action: addServer) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.borderless)
                .disabled(newPath.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // User-added servers (removable)
            if !userPaths.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Servers")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
            }

            Divider()

            Text("Changes to MCP servers require restarting apfel-gui.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 500)
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

    private func serverBadge(_ path: String) -> String {
        if path.contains("debug-tools") { return "bundled" }
        if path.contains("calculator") { return "apfel" }
        return "custom"
    }
}
