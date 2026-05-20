// ============================================================================
// main.swift - Entry point for apfel-gui
// Native macOS debug GUI for apfel.
// https://github.com/Arthur-Ficial/apfel-gui
// ============================================================================

import Foundation

let args = CommandLine.arguments

if args.contains("--help") || args.contains("-h") {
    print("""
    apfel-gui — native macOS debug GUI for apfel

    Usage:
      apfel-gui                     launch the GUI
      apfel-gui --api               also expose a local control API
      apfel-gui --list-mcp-servers  print configured user MCP server paths and exit
      apfel-gui --reset-mcp-servers clear user MCP server paths and exit
      apfel-gui --safe-mode         launch GUI without loading user MCP servers
      apfel-gui --help              show this help

    Recovery:
      If a malformed MCP path prevents the GUI from launching, run
      `apfel-gui --reset-mcp-servers` to clear all user-configured paths,
      then relaunch. Or use `--safe-mode` to bypass user paths for one session.
    """)
    exit(0)
}

if args.contains("--list-mcp-servers") {
    let paths = UserDefaults.standard.stringArray(forKey: "mcpServerPaths") ?? []
    if paths.isEmpty {
        print("No user MCP servers configured.")
    } else {
        print("User MCP servers (\(paths.count)):")
        for (i, p) in paths.enumerated() {
            print("  \(i + 1). \(p)")
        }
    }
    exit(0)
}

if args.contains("--reset-mcp-servers") {
    let existing = UserDefaults.standard.stringArray(forKey: "mcpServerPaths") ?? []
    UserDefaults.standard.removeObject(forKey: "mcpServerPaths")
    UserDefaults.standard.synchronize()
    if existing.isEmpty {
        print("No user MCP servers were configured. Nothing to reset.")
    } else {
        print("Cleared \(existing.count) user MCP server path\(existing.count == 1 ? "" : "s"):")
        for p in existing {
            print("  - \(p)")
        }
        print("\nRelaunch apfel-gui to start fresh.")
    }
    exit(0)
}

let enableAPI = args.contains("--api")
let safeMode = args.contains("--safe-mode")

startGUI(enableAPI: enableAPI, safeMode: safeMode)
