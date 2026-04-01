// ============================================================================
// Helpers.swift — Shared utilities for apfel-gui
// ============================================================================

import Foundation

private let stderr = FileHandle.standardError

/// Print a message to stderr with a trailing newline.
func printStderr(_ message: String) {
    stderr.write(Data("\(message)\n".utf8))
}
