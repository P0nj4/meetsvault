import AppKit
import SwiftUI

final class TermsWindowController: NSWindowController {
    convenience init() {
        let hosting = NSHostingController(rootView: TermsView())
        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(NSSize(width: 560, height: 520))
        window.styleMask = [.titled, .closable, .resizable]
        window.title = "Terms & Conditions"
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func show() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct TermsView: View {
    var body: some View {
        ScrollView {
            Text(Terms.text)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .textSelection(.enabled)
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}
