import AppKit
import SwiftUI

final class AboutWindowController: NSWindowController {
    convenience init() {
        let hosting = NSHostingController(rootView: AboutView())
        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(NSSize(width: 360, height: 220))
        window.styleMask = [.titled, .closable]
        window.title = "About MeetsVault"
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func show() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("MeetsVault")
                .font(.title2.bold())
            Text("Version \(appVersion)")
                .foregroundColor(.secondary)
            Text("Local meeting transcription. No cloud, no cost.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Open ~/Meetings") {
                let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Meetings")
                NSWorkspace.shared.open(url)
            }
        }
        .padding(32)
        .frame(width: 360, height: 220)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
