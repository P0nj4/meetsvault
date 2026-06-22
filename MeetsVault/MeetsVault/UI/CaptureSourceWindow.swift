import AppKit
import SwiftUI

// MARK: - Window controller

final class CaptureSourceWindowController: NSWindowController, NSWindowDelegate {
    private let onCancel: () -> Void
    private var didStart = false

    init(
        initialTitle: String?,
        onStart: @escaping (String?, CaptureMode) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onCancel = onCancel
        let view = CaptureSourceView(initialTitle: initialTitle, onStart: onStart)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(NSSize(width: 460, height: 390))
        window.styleMask = [.titled, .closable]
        window.title = "Audio source"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        didStart = true
        window?.close()
    }

    // Fires for a user-initiated close (title-bar X). The programmatic close on
    // Start sets `didStart` first, so onCancel only runs when the user dismisses
    // the dialog without starting — letting the controller reset and re-seed the
    // title on the next Start.
    func windowWillClose(_ notification: Notification) {
        guard !didStart else { return }
        onCancel()
    }
}

// MARK: - SwiftUI view

private let brandColor = Color(red: 0xFB / 255.0, green: 0x74 / 255.0, blue: 0x59 / 255.0)

private struct CaptureSourceView: View {
    let onStart: (String?, CaptureMode) -> Void

    @State private var meetingName: String
    @State private var selected: CaptureMode?
    @FocusState private var nameFocused: Bool

    init(
        initialTitle: String?,
        onStart: @escaping (String?, CaptureMode) -> Void
    ) {
        self.onStart = onStart
        _meetingName = State(initialValue: initialTitle ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Meeting name")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextField("Optional — e.g. Weekly Standup", text: $meetingName)
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFocused)
                }

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
                    if let mode = selected {
                        let trimmed = meetingName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onStart(trimmed.isEmpty ? nil : trimmed, mode)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selected == nil)
            }
            .padding(16)
        }
        .onAppear { nameFocused = true }
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
