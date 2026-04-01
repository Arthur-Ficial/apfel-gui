// ============================================================================
// LogViewer.swift — Live request log viewer with filtering
// Polls GET /v1/logs from the apfel server every 2 seconds.
// ============================================================================

import SwiftUI

struct LogViewer: View {
    let apiClient: APIClient
    @State private var logs: [APIClient.LogEntry] = []
    @State private var errorsOnly = false
    @State private var isPolling = true
    @State private var expandedLogIDs: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(.green)
                Text("Logs")
                    .font(.headline)
                Spacer()

                Toggle("Errors only", isOn: $errorsOnly)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Text("\(logs.count) entries")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Log table
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredLogs) { log in
                            logRow(log)
                                .id(log.id)
                        }
                    }
                }
                .onChange(of: logs.count) { _, _ in
                    if let lastId = filteredLogs.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
        .task {
            // Poll logs every 2 seconds
            while isPolling {
                do {
                    logs = try await apiClient.fetchLogs(errorsOnly: false, limit: 200)
                } catch {
                    // Silently ignore fetch errors
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .onDisappear { isPolling = false }
    }

    private var filteredLogs: [APIClient.LogEntry] {
        if errorsOnly {
            return logs.filter { $0.status >= 400 }
        }
        return logs
    }

    private func logRow(_ log: APIClient.LogEntry) -> some View {
        let isExpanded = expandedLogIDs.contains(log.id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(formatTimestamp(log.timestamp))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 70, alignment: .leading)

                Text("\(log.method) \(log.path)")
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)

                Spacer()

                if log.stream {
                    Text("SSE")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.orange)
                }

                Text("\(log.status)")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(log.status >= 400 ? .red : .green)

                Text("\(log.duration_ms)ms")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)

                if let tokens = log.estimated_tokens {
                    Text("~\(tokens)t")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 40, alignment: .trailing)
                }
            }

            if let error = log.error, !error.isEmpty {
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            if isExpanded {
                detailSection("Request", log.request_body)
                detailSection("Response", log.response_body)
                if let events = log.events, !events.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Events")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                            Text(event)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(log.status >= 400 ? Color.red.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if isExpanded {
                expandedLogIDs.remove(log.id)
            } else {
                expandedLogIDs.insert(log.id)
            }
        }
    }

    @ViewBuilder
    private func detailSection(_ title: String, _ content: String?) -> some View {
        if let content, !content.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(content)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    private func formatTimestamp(_ iso: String) -> String {
        // Extract HH:MM:SS from ISO 8601
        if let tIdx = iso.firstIndex(of: "T"),
           let zIdx = iso.firstIndex(of: "Z") ?? iso.lastIndex(of: "+") {
            let time = iso[iso.index(after: tIdx)..<zIdx]
            return String(time)
        }
        return iso
    }
}
