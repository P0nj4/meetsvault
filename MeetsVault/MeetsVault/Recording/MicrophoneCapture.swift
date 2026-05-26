import AVFoundation

final class MicrophoneCapture {
    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
    private(set) var firstSampleTime: Date?

    func start(to url: URL) throws {
        firstSampleTime = nil

        // Fix #3: build a fresh AVAudioEngine on every start. The inputNode is
        // bound to whichever audio input device was default at engine-creation
        // time, so reusing a long-lived engine across device changes (e.g. user
        // plugs in headphones between launching the recorder and pressing
        // Record) produces a stale node whose format no longer matches the
        // hardware — which makes installTap raise an NSException.
        let engine = AVAudioEngine()
        self.engine = engine

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Fix #1: validate the format before handing it to AVAudioEngine.
        // A degenerate format (0 channels or 0 Hz) means there is no usable
        // input device right now — fail with a Swift error instead of letting
        // installTap raise an Obj-C exception that aborts the process.
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            self.engine = nil
            throw CaptureError.invalidInputFormat(
                sampleRate: inputFormat.sampleRate,
                channels: inputFormat.channelCount
            )
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            self.engine = nil
            throw CaptureError.converterCreationFailed
        }

        audioFile = try AVAudioFile(forWriting: url, settings: targetFormat.settings, commonFormat: .pcmFormatInt16, interleaved: true)

        // Fix #2: wrap installTap in an Obj-C @try/@catch. Even with the format
        // check above, AVAudioEngine can still raise NSException if the device
        // changes between the format read and the tap install, or if the
        // engine's internal hw format disagrees with what outputFormat reports.
        // Converting it to a Swift error lets the caller surface a real failure
        // instead of crashing with SIGABRT.
        do {
            try ObjCExceptionCatcher.try {
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
            }
        } catch {
            audioFile = nil
            self.engine = nil
            throw CaptureError.audioEngineException((error as NSError).localizedDescription)
        }

        do {
            try ObjCExceptionCatcher.try {
                do {
                    try engine.start()
                } catch {
                    NSException(name: .internalInconsistencyException,
                                reason: error.localizedDescription,
                                userInfo: nil).raise()
                }
            }
        } catch {
            inputNode.removeTap(onBus: 0)
            audioFile = nil
            self.engine = nil
            throw CaptureError.audioEngineException((error as NSError).localizedDescription)
        }
    }

    func stop() {
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        engine = nil
        audioFile = nil
    }
}

