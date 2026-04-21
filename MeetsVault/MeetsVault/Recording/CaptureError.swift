import Foundation

enum CaptureError: Error {
    case converterCreationFailed
    case noDisplayFound
    case streamStartFailed(Error)
}
