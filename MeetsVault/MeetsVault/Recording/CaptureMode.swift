import Foundation

enum CaptureMode: String {
    /// Laptop speakers — only the microphone is recorded, no system audio.
    case micOnly
    /// Headphones — microphone + system audio captured in parallel (current behavior).
    case micAndSystem
}
