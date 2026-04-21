import SwiftUI

@main
struct MeetsVaultApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        SwiftUI.Settings { EmptyView() }
    }
}
