import AppKit
import SwiftUI

// MARK: - Window controller

final class CaptureSourceWindowController: NSWindowController {
    convenience init(onStart: @escaping (CaptureMode) -> Void, onCancel: @escaping () -> Void) {
        let view = CaptureSourceView(onStart: onStart, onCancel: onCancel)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(NSSize(width: 460, height: 320))
        window.styleMask = [.titled, .closable]
        window.title = "Audio source"
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func show() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        window?.close()
    }
}

// MARK: - SwiftUI view

private let brandColor = Color(red: 0xFB / 255.0, green: 0x74 / 255.0, blue: 0x59 / 255.0)

private struct CaptureSourceView: View {
    let onStart: (CaptureMode) -> Void
    let onCancel: () -> Void

    @State private var selected: CaptureMode?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("How are you listening to the meeting?")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    SourceCard(
                        symbol: "headphones",
                        title: "Headphones",
                        subtitle: "Records your voice and the call",
                        isSelected: selected == .micAndSystem
                    ) {
                        selected = .micAndSystem
                    }

                    SourceCard(
                        symbol: "laptopcomputer",
                        title: "Laptop speakers",
                        subtitle: "Records only your microphone",
                        isSelected: selected == .micOnly
                    ) {
                        selected = .micOnly
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Spacer()
                Button("Start Recording") {
                    if let mode = selected { onStart(mode) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selected == nil)
            }
            .padding(16)
        }
    }
}

private struct SourceCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 44, weight: .regular))
                    .foregroundColor(isSelected ? brandColor : .primary)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 170, height: 140)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? brandColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
