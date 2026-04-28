import AVFoundation

final class MicrophoneCapture {
    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
    private(set) var firstSampleTime: Date?

    func start(to url: URL) throws {
        firstSampleTime = nil
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw CaptureError.converterCreationFailed
        }

        audioFile = try AVAudioFile(forWriting: url, settings: targetFormat.settings, commonFormat: .pcmFormatInt16, interleaved: true)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let file = self.audioFile else { return }
            if self.firstSampleTime == nil {
                self.firstSampleTime = Date()
            }
            let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * self.targetFormat.sampleRate / inputFormat.sampleRate)
            guard let converted = AVAudioPCMBuffer(pcmFormat: self.targetFormat, frameCapacity: frameCapacity) else { return }

            var error: NSError?
            var haveData = false
            converter.convert(to: converted, error: &error) { _, outStatus in
                if haveData {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                haveData = true
                outStatus.pointee = .haveData
                return buffer
            }

            if error == nil, converted.frameLength > 0 {
                try? file.write(from: converted)
            }
        }

        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
    }
}
