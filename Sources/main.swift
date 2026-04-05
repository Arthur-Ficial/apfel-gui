// ============================================================================
// main.swift - Entry point for apfel-gui
// Native macOS debug GUI for apfel.
// https://github.com/Arthur-Ficial/apfel-gui
// ============================================================================

// Parse --api flag
let enableAPI = CommandLine.arguments.contains("--api")

startGUI(enableAPI: enableAPI)
