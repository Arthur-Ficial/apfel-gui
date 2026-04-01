// ============================================================================
// ContextStrategy.swift — Context window trimming strategy
// Duplicated from ApfelCore to keep apfel-gui fully independent.
// ============================================================================

/// Strategy for trimming conversation history when approaching the context limit.
enum ContextStrategy: String, Codable, Sendable, CaseIterable {
    case newestFirst = "newest-first"
    case oldestFirst = "oldest-first"
    case slidingWindow = "sliding-window"
    case summarize = "summarize"
    case strict = "strict"
}
