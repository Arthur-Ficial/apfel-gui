// ============================================================================
// GUIApp.swift — Launch native macOS SwiftUI GUI for apfel
// Spawns apfel --serve with --mcp flags, opens SwiftUI window.
// ============================================================================

import AppKit
import SwiftUI

/// Port for the GUI's own apfel server instance. Avoids apfel defaults (11434/11435).
let apfelGUIPort = 11438

/// Start the GUI: launch server in background, open SwiftUI chat window.
@MainActor
func startGUI(enableAPI: Bool = false) {
    let port = apfelGUIPort

    // Find apfel in PATH or fall back to /usr/local/bin/apfel
    let apfelPath: String
    if let resolved = ProcessInfo.processInfo.environment["PATH"]?
        .split(separator: ":").map({ "\($0)/apfel" })
        .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
        apfelPath = resolved
    } else if FileManager.default.isExecutableFile(atPath: "/usr/local/bin/apfel") {
        apfelPath = "/usr/local/bin/apfel"
    } else {
        printStderr("GUI: error: 'apfel' not found in PATH. Install it: brew install Arthur-Ficial/tap/apfel")
        return
    }

    // Discover MCP servers
    let mcpPaths = discoverMCPServers(apfelBinaryPath: apfelPath)

    var arguments = ["--serve", "--port", "\(port)", "--cors", "--debug"]
    for path in mcpPaths {
        arguments.append(contentsOf: ["--mcp", path])
    }

    let serverProcess = Process()
    serverProcess.executableURL = URL(fileURLWithPath: apfelPath)
    serverProcess.arguments = arguments
    serverProcess.standardOutput = FileHandle.nullDevice
    serverProcess.standardError = FileHandle.nullDevice

    do {
        try serverProcess.run()
        printStderr("GUI: server started on port \(port) (PID: \(serverProcess.processIdentifier))")
        if !mcpPaths.isEmpty {
            printStderr("GUI: MCP servers: \(mcpPaths.joined(separator: ", "))")
        }
    } catch {
        printStderr("GUI: failed to start server: \(error)")
        return
    }

    // Wait for server to be ready (longer timeout when MCP servers are loading)
    let client = APIClient(port: port)
    let timeout = mcpPaths.isEmpty ? 8.0 : 12.0
    let ready = waitForServer(client: client, timeout: timeout)
    guard ready else {
        printStderr("GUI: server failed to start within \(Int(timeout)) seconds")
        serverProcess.terminate()
        return
    }
    printStderr("GUI: server ready")

    // Launch the SwiftUI app
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)

    // Build the full launch command string for display
    let launchCommand = ([apfelPath] + arguments).map { arg in
        arg.contains(" ") ? "\"\(arg)\"" : arg
    }.joined(separator: " ")

    let delegate = GUIAppDelegate(
        serverProcess: serverProcess,
        apiClient: client,
        mcpPaths: mcpPaths,
        serverLaunchCommand: launchCommand,
        enableAPI: enableAPI
    )
    app.delegate = delegate
    app.run()
}

// MARK: - MCP Server Discovery

/// Find MCP servers to enable by default.
/// Returns paths to .py scripts or executables that exist.
private func discoverMCPServers(apfelBinaryPath: String) -> [String] {
    let fm = FileManager.default
    var paths: [String] = []

    // 1. Bundled debug-tools server (shipped with apfel-gui)
    let bundledCandidates = bundledMCPServerCandidates()
    if let debugTools = bundledCandidates.first(where: { fm.isReadableFile(atPath: $0) }) {
        paths.append(debugTools)
        printStderr("GUI: found bundled MCP server: \(debugTools)")
    }

    // 2. apfel's calculator MCP server (from apfel source repo)
    let calcCandidates = calculatorMCPServerCandidates(apfelBinaryPath: apfelBinaryPath)
    if let calculator = calcCandidates.first(where: { fm.isReadableFile(atPath: $0) }) {
        paths.append(calculator)
        printStderr("GUI: found calculator MCP server: \(calculator)")
    }

    // 3. User-configured MCP servers (from UserDefaults)
    if let userPaths = UserDefaults.standard.stringArray(forKey: "mcpServerPaths") {
        for path in userPaths {
            if fm.isReadableFile(atPath: path) {
                paths.append(path)
                printStderr("GUI: found user MCP server: \(path)")
            } else {
                printStderr("GUI: user MCP server not found: \(path)")
            }
        }
    }

    return paths
}

/// Candidate paths for the bundled debug-tools MCP server.
private func bundledMCPServerCandidates() -> [String] {
    var candidates: [String] = []

    // Relative to the executable (for swift run / dev builds)
    let execPath = CommandLine.arguments[0]
    let execDir = URL(fileURLWithPath: execPath).deletingLastPathComponent().path

    // Walk up from .build/debug/apfel-gui to repo root
    let repoRoot = URL(fileURLWithPath: execDir)
        .deletingLastPathComponent() // .build/debug -> .build
        .deletingLastPathComponent() // .build -> repo root
        .deletingLastPathComponent() // one more level for release builds
    candidates.append(repoRoot.appendingPathComponent("mcp/debug-tools/server.py").path)

    // Also check from the repo root directly (2 levels up)
    let repoRoot2 = URL(fileURLWithPath: execDir)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    candidates.append(repoRoot2.appendingPathComponent("mcp/debug-tools/server.py").path)

    // Current working directory (for running from repo root)
    candidates.append(FileManager.default.currentDirectoryPath + "/mcp/debug-tools/server.py")

    // Installed locations
    candidates.append("/opt/homebrew/share/apfel-gui/mcp/debug-tools/server.py")
    candidates.append("/usr/local/share/apfel-gui/mcp/debug-tools/server.py")

    return candidates
}

/// Candidate paths for apfel's calculator MCP server.
private func calculatorMCPServerCandidates(apfelBinaryPath: String) -> [String] {
    var candidates: [String] = []
    let home = FileManager.default.homeDirectoryForCurrentUser.path

    // Relative to the apfel binary (Homebrew or dev)
    let apfelDir = URL(fileURLWithPath: apfelBinaryPath).deletingLastPathComponent()
    candidates.append(apfelDir.deletingLastPathComponent().appendingPathComponent("mcp/calculator/server.py").path)

    // Common dev paths
    candidates.append("\(home)/dev/apfel/mcp/calculator/server.py")
    candidates.append("\(home)/Developer/apfel/mcp/calculator/server.py")
    candidates.append("\(home)/src/apfel/mcp/calculator/server.py")
    candidates.append("\(home)/projects/apfel/mcp/calculator/server.py")

    // Homebrew share path
    candidates.append("/opt/homebrew/share/apfel/mcp/calculator/server.py")
    candidates.append("/usr/local/share/apfel/mcp/calculator/server.py")

    return candidates
}

/// Poll /health until server responds or timeout.
private func waitForServer(client: APIClient, timeout: Double) -> Bool {
    let start = Date()
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var isReady = false

    Task { @Sendable in
        while Date().timeIntervalSince(start) < timeout {
            if await client.healthCheck() {
                isReady = true
                semaphore.signal()
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
        semaphore.signal()
    }

    semaphore.wait()
    return isReady
}

// MARK: - App Delegate

@MainActor
class GUIAppDelegate: NSObject, NSApplicationDelegate {
    let serverProcess: Process
    let apiClient: APIClient
    let mcpPaths: [String]
    let serverLaunchCommand: String
    let enableAPI: Bool
    var window: NSWindow?
    var viewModel: ChatViewModel?
    var controlServer: GUIControlServer?

    init(serverProcess: Process, apiClient: APIClient, mcpPaths: [String], serverLaunchCommand: String, enableAPI: Bool) {
        self.serverProcess = serverProcess
        self.apiClient = apiClient
        self.mcpPaths = mcpPaths
        self.serverLaunchCommand = serverLaunchCommand
        self.enableAPI = enableAPI
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewModel = ChatViewModel(apiClient: apiClient)
        viewModel.mcpServerPaths = mcpPaths
        viewModel.serverLaunchCommand = serverLaunchCommand
        self.viewModel = viewModel

        // Start GUI control API if --api flag was passed
        if enableAPI {
            let ctrl = GUIControlServer(viewModel: viewModel)
            ctrl.start()
            self.controlServer = ctrl
        }
        let contentView = MainWindow(viewModel: viewModel, apiClient: apiClient)
        NSApp.mainMenu = buildMainMenu()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "apfel - Apple Intelligence"
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if serverProcess.isRunning {
            serverProcess.terminate()
            printStderr("GUI: server process terminated")
        }
    }

    private func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit apfel", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let actionsMenuItem = NSMenuItem()
        mainMenu.addItem(actionsMenuItem)
        let actionsMenu = NSMenu(title: "Actions")
        actionsMenuItem.submenu = actionsMenu

        let selfDiscussItem = NSMenuItem(title: "Self-Discuss…", action: #selector(openSelfDiscussion), keyEquivalent: "j")
        selfDiscussItem.target = self
        actionsMenu.addItem(selfDiscussItem)

        let clearItem = NSMenuItem(title: "Clear Chat", action: #selector(clearChat), keyEquivalent: "k")
        clearItem.target = self
        actionsMenu.addItem(clearItem)

        return mainMenu
    }

    @objc
    private func openSelfDiscussion() {
        viewModel?.showSelfDiscussion = true
    }

    @objc
    private func clearChat() {
        viewModel?.clear()
    }
}
