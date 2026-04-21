import AVFoundation
import ScreenCaptureKit

final class SystemAudioCapture: NSObject {
    private var stream: SCStream?
    private var audioFile: AVAudioFile?
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
    private var converter: AVAudioConverter?

    func start(to url: URL) async throws {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw CaptureError.noDisplayFound
        }

        // Capture all system audio, excluding our own process
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 2

        // Prepare target file
        audioFile = try AVAudioFile(forWriting: url, settings: targetFormat.settings, commonFormat: .pcmFormatInt16, interleaved: true)

        // Build converter from 48kHz stereo → 16kHz mono
        let sourceFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        converter = AVAudioConverter(from: sourceFormat, to: targetFormat)

        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "com.germanpereyra.meetsvault.systemaudio"))

        do {
            try await stream?.startCapture()
        } catch {
            throw CaptureError.streamStartFailed(error)
        }
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
        audioFile = nil
        converter = nil
    }
}

// MARK: - SCStreamOutput

extension SystemAudioCapture: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard let converter, let audioFile else { return }

        guard let formatDescription = sampleBuffer.formatDescription else { return }

        let audioDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        guard let desc = audioDesc else { return }

        let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: desc.pointee.mSampleRate,
            channels: AVAudioChannelCount(desc.pointee.mChannelsPerFrame),
            interleaved: desc.pointee.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
        )!

        let frameCount = AVAudioFrameCount(sampleBuffer.numSamples)
        guard let sourceBuf = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else { return }
        sourceBuf.frameLength = frameCount

        // Determine buffer list size and allocate appropriately
        var bufferListSizeNeeded: Int = 0
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &bufferListSizeNeeded,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: nil
        )

        let rawPtr = UnsafeMutableRawPointer.allocate(byteCount: bufferListSizeNeeded, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { rawPtr.deallocate() }
        let abl = rawPtr.bindMemory(to: AudioBufferList.self, capacity: 1)
        var retainedBlockBuffer: CMBlockBuffer?
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: abl,
            bufferListSize: bufferListSizeNeeded,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &retainedBlockBuffer
        )

        let bufferCount = Int(abl.pointee.mNumberBuffers)
        withUnsafePointer(to: &abl.pointee.mBuffers) { ptr in
            let buffers = UnsafeBufferPointer(start: ptr, count: bufferCount)
            let dstABL = sourceBuf.mutableAudioBufferList
            for i in 0..<min(bufferCount, Int(dstABL.pointee.mNumberBuffers)) {
                let src = buffers[i]
                let dst = UnsafeMutableAudioBufferListPointer(dstABL)[i]
                let bytes = min(Int(src.mDataByteSize), Int(dst.mDataByteSize))
                if let srcData = src.mData, let dstData = dst.mData {
                    memcpy(dstData, srcData, bytes)
                }
            }
        }

        let capacity = AVAudioFrameCount(Double(frameCount) * targetFormat.sampleRate / sourceFormat.sampleRate) + 1
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var error: NSError?
        var haveData = false
        converter.convert(to: converted, error: &error) { _, outStatus in
            if haveData {
                outStatus.pointee = .noDataNow
                return nil
            }
            haveData = true
            outStatus.pointee = .haveData
            return sourceBuf
        }

        if error == nil, converted.frameLength > 0 {
            try? audioFile.write(from: converted)
        }
    }
}

// MARK: - SCStreamDelegate

extension SystemAudioCapture: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("[MeetsVault] System audio stream stopped: %@", error.localizedDescription)
    }
}
