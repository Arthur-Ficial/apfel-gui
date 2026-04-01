// ============================================================================
// GUIApp.swift — Launch native macOS SwiftUI GUI for apfel
// Spawns apfel --serve as background process, opens SwiftUI window.
// ============================================================================

import AppKit
import SwiftUI

/// Start the GUI: launch server in background, open SwiftUI chat window.
@MainActor
func startGUI() {
    // Pick a port for the background server
    let port = 11434

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

    let serverProcess = Process()
    serverProcess.executableURL = URL(fileURLWithPath: apfelPath)
    serverProcess.arguments = ["--serve", "--port", "\(port)", "--cors"]
    serverProcess.standardOutput = FileHandle.nullDevice
    serverProcess.standardError = FileHandle.nullDevice

    do {
        try serverProcess.run()
        printStderr("GUI: server started on port \(port) (PID: \(serverProcess.processIdentifier))")
    } catch {
        printStderr("GUI: failed to start server: \(error)")
        return
    }

    // Wait for server to be ready
    let client = APIClient(port: port)
    let ready = waitForServer(client: client, timeout: 8.0)
    guard ready else {
        printStderr("GUI: server failed to start within 8 seconds")
        serverProcess.terminate()
        return
    }
    printStderr("GUI: server ready")

    // Launch the SwiftUI app
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)

    let delegate = GUIAppDelegate(
        serverProcess: serverProcess,
        apiClient: client
    )
    app.delegate = delegate
    app.run()
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
    var window: NSWindow?
    var viewModel: ChatViewModel?

    init(serverProcess: Process, apiClient: APIClient) {
        self.serverProcess = serverProcess
        self.apiClient = apiClient
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewModel = ChatViewModel(apiClient: apiClient)
        self.viewModel = viewModel
        let contentView = MainWindow(viewModel: viewModel, apiClient: apiClient)
        NSApp.mainMenu = buildMainMenu()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "apfel — Apple Intelligence"
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
        // Clean shutdown: kill the server process
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
