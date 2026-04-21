import AppKit

enum MenuBarIconState {
    case idle
    case recording
    case transcribing

    var symbolName: String {
        switch self {
        case .idle: return "waveform"
        case .recording: return "record.circle.fill"
        case .transcribing: return "waveform.badge.magnifyingglass"
        }
    }

    var tintColor: NSColor? {
        switch self {
        case .recording: return .systemRed
        default: return nil
        }
    }

    var image: NSImage {
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)!
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let configured = img.withSymbolConfiguration(config)!
        if let color = tintColor {
            return configured.tinted(with: color)
        }
        configured.isTemplate = true
        return configured
    }
}

private extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let copy = self.copy() as! NSImage
        copy.lockFocus()
        color.set()
        NSRect(origin: .zero, size: copy.size).fill(using: .sourceAtop)
        copy.unlockFocus()
        return copy
    }
}
