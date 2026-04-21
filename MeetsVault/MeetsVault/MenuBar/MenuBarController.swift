import AppKit

final class MenuBarController {
    private let statusItem: NSStatusItem
    private(set) var recorder: AudioRecorder?
    private var iconState: MenuBarIconState = .idle {
        didSet { updateIcon() }
    }

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        buildMenu()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Icon

    private func updateIcon() {
        statusItem.button?.image = iconState.image
        statusItem.button?.toolTip = "MeetsVault"
    }

    // MARK: - Menu

    func buildMenu() {
        let menu = NSMenu()

        let startItem = NSMenuItem(title: "Start Recording", action: #selector(startRecording), keyEquivalent: "")
        startItem.target = self
        menu.addItem(startItem)

        menu.addItem(.separator())

        let openFolderItem = NSMenuItem(title: "Open Meetings Folder", action: #selector(openMeetingsFolder), keyEquivalent: "")
        openFolderItem.target = self
        menu.addItem(openFolderItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit MeetsVault", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func startRecording() {
        NSLog("[MeetsVault] Start Recording tapped (not yet implemented)")
    }

    @objc private func openMeetingsFolder() {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Meetings")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
}
