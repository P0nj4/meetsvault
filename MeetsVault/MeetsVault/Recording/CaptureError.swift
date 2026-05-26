import Foundation

enum CaptureError: Error {
    case converterCreationFailed
    case noDisplayFound
    case streamStartFailed(Error)
    case invalidInputFormat(sampleRate: Double, channels: UInt32)
    case audioEngineException(String)
}
