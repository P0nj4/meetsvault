import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var welcomeWindowController: WelcomeWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = NotificationManager.shared  // initialize delegate early
        NotificationManager.shared.requestAuthorizationIfNeeded()
        registerURLSchemeHandler()
        menuBarController = MenuBarController()
        AudioRetentionJob.run()

        if !Settings.shared.hasCompletedOnboarding {
            showWelcomeWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController = nil
    }

    // MARK: - Welcome

    private func showWelcomeWindow() {
        let wc = WelcomeWindowController { [weak self] in
            self?.welcomeWindowController?.closeWindow()
            self?.welcomeWindowController = nil
        }
        wc.show()
        welcomeWindowController = wc
    }

    // MARK: - URL Scheme

    private func registerURLSchemeHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        guard
            let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString)
        else { return }

        NSLog("[MeetsVault] Received URL: %@", urlString)
        URLSchemeHandler.handle(url, recorder: menuBarController?.recorder)
    }
}
