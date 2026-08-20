import AVFoundation
import Foundation

enum AudioImportService {
    struct Probe: Sendable {
        var duration: Double
        var sampleRate: Double
        var channels: Int
    }

    enum ImportError: LocalizedError {
        case unsupported(String)
        case conversionFailed(String)

        var errorDescription: String? {
            switch self {
            case .unsupported(let name): "\(name) is not a supported or readable audio file."
            case .conversionFailed(let detail): "Audio conversion failed: \(detail)"
            }
        }
    }

    static func probe(url: URL) throws -> Probe {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            return Probe(
                duration: Double(file.length) / format.sampleRate,
                sampleRate: format.sampleRate,
                channels: Int(format.channelCount)
            )
        } catch {
            throw ImportError.unsupported(url.lastPathComponent)
        }
    }

    static func ensureNativeReadable(url: URL, workingDirectory: URL) throws -> URL {
        if (try? AVAudioFile(forReading: url)) != nil { return url }
        guard let ffmpeg = locateFFmpeg() else { throw ImportError.unsupported(url.lastPathComponent) }

        let output = workingDirectory.appendingPathComponent("\(UUID().uuidString).caf")
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = [
            "-hide_banner", "-loglevel", "error", "-y",
            "-i", url.path,
            "-vn", "-acodec", "pcm_f32le", output.path
        ]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ImportError.conversionFailed(error.localizedDescription)
        }
        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(decoding: data, as: UTF8.self)
            throw ImportError.conversionFailed(message.isEmpty ? "FFmpeg exited with status \(process.terminationStatus)." : message)
        }
        return output
    }

    static func locateFFmpeg() -> URL? {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("ffmpeg").path,
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ].compactMap { $0 }
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
    }
}
