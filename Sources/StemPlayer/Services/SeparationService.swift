import Foundation

@MainActor
final class SeparationService: ObservableObject {
    enum State: Equatable {
        case idle
        case preparing
        case running(progress: Double, message: String)
        case completed
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .preparing, .running: true
            default: false
            }
        }
    }

    struct Result: Sendable {
        var drums: URL
        var bass: URL
        var vocals: URL
        var other: URL
    }

    enum SeparationError: LocalizedError {
        case helperMissing
        case failed(String)
        case incompleteOutput

        var errorDescription: String? {
            switch self {
            case .helperMissing:
                "The local separation helper is not installed in this build. Prepared stems still work normally."
            case .failed(let detail): "Stem separation failed: \(detail)"
            case .incompleteOutput: "The separator finished without producing all four stems."
            }
        }
    }

    @Published private(set) var state: State = .idle
    private var process: Process?

    func cancel() {
        process?.terminate()
        process = nil
        state = .idle
    }

    func separate(input: URL, outputDirectory: URL) async throws -> Result {
        state = .preparing
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        guard let helper = locateHelper() else {
            state = .failed(SeparationError.helperMissing.localizedDescription)
            throw SeparationError.helperMissing
        }

        let runningProcess = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        runningProcess.executableURL = helper
        runningProcess.arguments = ["split", "--input", input.path, "--output", outputDirectory.path]
        runningProcess.standardOutput = outputPipe
        runningProcess.standardError = errorPipe
        process = runningProcess
        state = .running(progress: 0.02, message: "Starting local separator…")

        let outputTask = Task { [weak self] in
            for try await line in outputPipe.fileHandleForReading.bytes.lines {
                self?.consume(line: line)
            }
        }
        do {
            try runningProcess.run()
        } catch {
            state = .failed(error.localizedDescription)
            throw SeparationError.failed(error.localizedDescription)
        }

        let status = await withCheckedContinuation { continuation in
            runningProcess.terminationHandler = { process in continuation.resume(returning: process.terminationStatus) }
        }
        outputTask.cancel()
        process = nil

        guard status == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let detail = String(decoding: data, as: UTF8.self)
            state = .failed(detail)
            throw SeparationError.failed(detail.isEmpty ? "Helper exited with status \(status)." : detail)
        }

        let files = try FileManager.default.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: nil)
        func find(_ role: String) -> URL? {
            files.first { $0.deletingPathExtension().lastPathComponent.lowercased().contains(role) }
        }
        guard let drums = find("drum"), let bass = find("bass"),
              let vocals = find("vocal"), let other = find("other") else {
            state = .failed(SeparationError.incompleteOutput.localizedDescription)
            throw SeparationError.incompleteOutput
        }
        state = .completed
        return Result(drums: drums, bass: bass, vocals: vocals, other: other)
    }

    private func consume(line: String) {
        if let data = line.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let progress = object["progress"] as? Double ?? 0.1
            let message = object["message"] as? String ?? "Separating…"
            state = .running(progress: max(0, min(1, progress)), message: message)
        } else if !line.isEmpty {
            state = .running(progress: 0.15, message: line)
        }
    }

    private func locateHelper() -> URL? {
        let executableName = "stem-worker"
        var candidates: [URL] = []
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent(executableName))
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        candidates.append(cwd.appendingPathComponent("Helpers/stem-worker/target/release/stem-worker"))
        candidates.append(cwd.appendingPathComponent(".build/stem-worker"))
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
