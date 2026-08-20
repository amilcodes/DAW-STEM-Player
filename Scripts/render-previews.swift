import AppKit
import SwiftUI

@main
struct PreviewRenderer {
    @MainActor
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw PreviewError.missingOutputDirectory
        }

        let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let warmupApp = previewApp(mode: .mix)
        for _ in 0..<2 {
            let warmup = ImageRenderer(content: previewView(app: warmupApp))
            warmup.scale = 2
            _ = warmup.nsImage?.tiffRepresentation
        }

        for mode in WorkspaceMode.allCases {
            let app = previewApp(mode: mode)
            for _ in 0..<2 {
                let preflight = ImageRenderer(content: previewView(app: app))
                preflight.scale = 2
                _ = preflight.nsImage?.tiffRepresentation
            }

            let renderer = ImageRenderer(content: previewView(app: app))
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                throw PreviewError.renderFailed(mode.rawValue)
            }
            try png.write(to: outputDirectory.appendingPathComponent("\(mode.rawValue.lowercased()).png"))
        }
    }

    @MainActor
    private static func previewApp(mode: WorkspaceMode) -> AppState {
        let app = AppState()
        let stems = [
            StemModel(role: .drums, relativePath: "preview-drums.wav", gainDB: -1.5, pan: -0.08, tone: 0.16),
            StemModel(role: .vocals, relativePath: "preview-vocals.wav", gainDB: -3.2, pan: 0, tone: 0.08),
            StemModel(role: .instruments, relativePath: "preview-other.wav", gainDB: -5.8, pan: 0.18, tone: -0.12),
            StemModel(role: .bass, relativePath: "preview-bass.wav", gainDB: -2.4, pan: 0, tone: -0.22)
        ]
        app.project = StemProject(
            title: "Borough Session",
            durationSeconds: 194.7,
            stems: stems,
            pattern: previewPattern()
        )
        app.selectedStemID = stems[0].id
        app.selectedPadIndex = 1
        app.mode = mode
        app.waveforms = Dictionary(uniqueKeysWithValues: stems.enumerated().map { index, stem in
            let peaks = (0..<420).map { sample -> Float in
                let x = Double(sample) / 420
                let carrier = abs(sin(x * Double.pi * Double(18 + index * 5)))
                let envelope = 0.22 + 0.72 * abs(sin(x * Double.pi * Double(2 + index)))
                return Float(min(1, carrier * envelope * (0.74 + Double(index) * 0.05)))
            }
            return (stem.id, peaks)
        })
        return app
    }

    @MainActor
    private static func previewView(app: AppState) -> some View {
        RootView()
            .environmentObject(app)
            .environmentObject(app.audio)
            .preferredColorScheme(.light)
            .frame(width: 320, height: 520)
    }

    private static func previewPattern() -> DrumPattern {
        var pattern = DrumPattern(bpm: 104, bars: 2, swing: 0.12)
        let hits: [(Int, Int, Float)] = [
            (0, 0, 1), (0, 4, 0.82), (0, 8, 1), (0, 11, 0.55), (0, 12, 0.88),
            (1, 4, 0.92), (1, 12, 0.94),
            (2, 0, 0.58), (2, 2, 0.46), (2, 4, 0.62), (2, 6, 0.48),
            (2, 8, 0.64), (2, 10, 0.48), (2, 12, 0.66), (2, 14, 0.52),
            (3, 7, 0.52), (3, 15, 0.68)
        ]
        pattern.events = hits.map { pad, step, velocity in
            PatternEvent(padIndex: pad, beat: Double(step) / 4, velocity: velocity)
        }
        return pattern
    }

    enum PreviewError: LocalizedError {
        case missingOutputDirectory
        case renderFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingOutputDirectory: "Usage: render-previews OUTPUT_DIRECTORY"
            case .renderFailed(let mode): "Could not render the \(mode) preview."
            }
        }
    }
}
