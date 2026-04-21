import AVFoundation
import ScreenCaptureKit

enum PermissionsChecker {
    static var microphoneGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static var screenRecordingGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    static func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
    }
}
