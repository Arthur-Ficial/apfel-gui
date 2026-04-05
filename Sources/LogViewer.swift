// ============================================================================
// LogViewer.swift — Live request log viewer with filtering and stats
// Polls GET /v1/logs and /v1/logs/stats from the apfel server.
// ============================================================================

import SwiftUI

struct LogViewer: View {
    let apiClient: APIClient
    @State private var logs: [APIClient.LogEntry] = []
    @State private var stats: APIClient.ServerStats?
    @State private var errorsOnly = false
    @State private var isPolling = true
    @State private var expandedLogIDs: Set<String> = []
    @State private var pathFilter: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header with stats
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(.green)
                Text("Logs")
                    .font(.headline)

                if let stats {
                    Divider().frame(height: 12)
                    statBadge("\(stats.total_requests) req", color: .blue)
                    statBadge("\(stats.total_errors) err", color: stats.total_errors > 0 ? .red : .green)
                    statBadge("\(stats.avg_duration_ms)ms avg", color: .orange)
                    if let tokens = stats.estimated_tokens_total {
                        statBadge("~\(formatNumber(tokens))t", color: .purple)
                    }
                    statBadge(formatUptime(stats.uptime_seconds), color: .secondary)
                    if stats.active_requests > 0 {
                        statBadge("\(stats.active_requests) active", color: .cyan)
                    }
                }

                Spacer()

                // Path filter
                TextField("Filter path...", text: $pathFilter)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption2, design: .monospaced))
                    .frame(width: 120)

                Toggle("Errors only", isOn: $errorsOnly)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Text("\(filteredLogs.count) entries")
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
            while isPolling {
                do {
                    async let logsResult = apiClient.fetchLogs(errorsOnly: false, limit: 200)
                    async let statsResult: APIClient.ServerStats? = {
                        try? await apiClient.fetchStats()
                    }()
                    logs = try await logsResult
                    stats = await statsResult
                } catch {
                    // Silently ignore — server might not have --debug enabled
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .onDisappear { isPolling = false }
    }

    private var filteredLogs: [APIClient.LogEntry] {
        var result = logs
        if errorsOnly {
            result = result.filter { $0.status >= 400 }
        }
        if !pathFilter.isEmpty {
            result = result.filter { $0.path.localizedCaseInsensitiveContains(pathFilter) }
        }
        return result
    }

    private func logRow(_ log: APIClient.LogEntry) -> some View {
        let isExpanded = expandedLogIDs.contains(log.id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(formatTimestamp(log.timestamp))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 70, alignment: .leading)

                Text(log.method)
                    .font(.system(.caption2, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)

                Text(log.path)
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
                    .foregroundStyle(statusColor(log.status))

                Text("\(log.duration_ms)ms")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 55, alignment: .trailing)

                if let tokens = log.estimated_tokens {
                    Text("~\(tokens)t")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 45, alignment: .trailing)
                }

                // Expand/collapse indicator
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }

            if let error = log.error, !error.isEmpty {
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    detailSection("Request Body", log.request_body)
                    detailSection("Response Body", log.response_body)
                    if let events = log.events, !events.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Events")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                                HStack(spacing: 4) {
                                    Text("\(idx + 1).")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.quaternary)
                                        .frame(width: 20, alignment: .trailing)
                                    Text(event)
                                        .font(.system(.caption2, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 78)
                .padding(.top, 4)
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
                HStack {
                    Text(title)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    CopyButton(text: content)
                }
                Text(content)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(20)
            }
        }
    }

    @ViewBuilder
    private func statBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(color)
    }

    private func statusColor(_ status: Int) -> Color {
        switch status {
        case 200..<300: return .green
        case 400..<500: return .orange
        case 500...: return .red
        default: return .secondary
        }
    }

    private func formatTimestamp(_ iso: String) -> String {
        if let tIdx = iso.firstIndex(of: "T"),
           let zIdx = iso.firstIndex(of: "Z") ?? iso.lastIndex(of: "+") {
            let time = iso[iso.index(after: tIdx)..<zIdx]
            return String(time)
        }
        return iso
    }

    private func formatUptime(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return "\(n / 1_000_000)M" }
        if n >= 1_000 { return "\(n / 1_000)K" }
        return "\(n)"
    }
}
