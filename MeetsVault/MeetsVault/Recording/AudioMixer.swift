import AVFoundation

enum AudioMixer {
    /// Mix mic.wav and system.wav at equal gain into combined.wav.
    /// Both inputs must be 16 kHz mono PCM Int16.
    static func mix(mic micURL: URL, system systemURL: URL, output outputURL: URL) throws {
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!

        let micFile = try AVAudioFile(forReading: micURL, commonFormat: .pcmFormatFloat32, interleaved: false)
        let systemFile = try AVAudioFile(forReading: systemURL, commonFormat: .pcmFormatFloat32, interleaved: false)

        let readFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let outputFrameCount = max(AVAudioFrameCount(micFile.length), AVAudioFrameCount(systemFile.length))

        guard let micBuf = AVAudioPCMBuffer(pcmFormat: readFormat, frameCapacity: outputFrameCount),
              let systemBuf = AVAudioPCMBuffer(pcmFormat: readFormat, frameCapacity: outputFrameCount),
              let outputBuf = AVAudioPCMBuffer(pcmFormat: readFormat, frameCapacity: outputFrameCount)
        else { throw MixerError.bufferAllocationFailed }

        micBuf.frameLength = outputFrameCount
        systemBuf.frameLength = outputFrameCount
        outputBuf.frameLength = outputFrameCount

        // Zero-fill both buffers first (handles the case where one is shorter)
        if let ptr = micBuf.floatChannelData?[0] {
            ptr.initialize(repeating: 0, count: Int(outputFrameCount))
        }
        if let ptr = systemBuf.floatChannelData?[0] {
            ptr.initialize(repeating: 0, count: Int(outputFrameCount))
        }

        // Read actual samples (only as many frames as available)
        let micReadBuf = AVAudioPCMBuffer(pcmFormat: readFormat, frameCapacity: AVAudioFrameCount(micFile.length))!
        let systemReadBuf = AVAudioPCMBuffer(pcmFormat: readFormat, frameCapacity: AVAudioFrameCount(systemFile.length))!
        try micFile.read(into: micReadBuf)
        try systemFile.read(into: systemReadBuf)

        // Sum at equal gain (0.5 each to prevent clipping)
        let outPtr = outputBuf.floatChannelData![0]
        let micPtr = micReadBuf.floatChannelData![0]
        let sysPtr = systemReadBuf.floatChannelData![0]

        let micFrames = Int(micReadBuf.frameLength)
        let sysFrames = Int(systemReadBuf.frameLength)
        let totalFrames = Int(outputFrameCount)

        for i in 0..<totalFrames {
            let m: Float = i < micFrames ? micPtr[i] * 0.5 : 0
            let s: Float = i < sysFrames ? sysPtr[i] * 0.5 : 0
            outPtr[i] = m + s
        }

        // Write to output as PCM Int16
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: format.settings, commonFormat: .pcmFormatInt16, interleaved: true)

        // Convert float → int16
        guard let int16Buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputFrameCount),
              let converter = AVAudioConverter(from: readFormat, to: format)
        else { throw MixerError.converterCreationFailed }

        var haveData = false
        var error: NSError?
        converter.convert(to: int16Buf, error: &error) { _, outStatus in
            if haveData { outStatus.pointee = .noDataNow; return nil }
            haveData = true
            outStatus.pointee = .haveData
            return outputBuf
        }
        guard error == nil else { throw MixerError.conversionFailed(error!) }
        try outputFile.write(from: int16Buf)
    }
}

enum MixerError: Error {
    case bufferAllocationFailed
    case converterCreationFailed
    case conversionFailed(Error)
}
