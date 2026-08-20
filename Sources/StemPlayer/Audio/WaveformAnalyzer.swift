import Accelerate
import AVFoundation
import Foundation

enum WaveformAnalyzer {
    struct Result: Sendable {
        var peaks: [Float]
        var duration: Double
        var sampleRate: Double
        var channelCount: Int
    }

    static func analyze(url: URL, targetPeakCount: Int = 1_600) throws -> Result {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let totalFrames = max(1, Int(file.length))
        let bucketSize = max(64, totalFrames / max(1, targetPeakCount))
        let readSize = AVAudioFrameCount(min(max(bucketSize, 4_096), 65_536))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: readSize) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var peaks: [Float] = []
        peaks.reserveCapacity(targetPeakCount + 2)
        var bucketPeak: Float = 0
        var bucketFrames = 0

        while file.framePosition < file.length {
            try file.read(into: buffer, frameCount: readSize)
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0, let channels = buffer.floatChannelData else { break }
            let channelCount = Int(format.channelCount)

            for frame in 0..<frameLength {
                var samplePeak: Float = 0
                for channel in 0..<channelCount {
                    samplePeak = max(samplePeak, abs(channels[channel][frame]))
                }
                bucketPeak = max(bucketPeak, samplePeak)
                bucketFrames += 1
                if bucketFrames >= bucketSize {
                    peaks.append(min(1, bucketPeak))
                    bucketPeak = 0
                    bucketFrames = 0
                }
            }
        }

        if bucketFrames > 0 { peaks.append(min(1, bucketPeak)) }
        if peaks.isEmpty { peaks = [0] }

        return Result(
            peaks: peaks,
            duration: Double(file.length) / format.sampleRate,
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount)
        )
    }
}
