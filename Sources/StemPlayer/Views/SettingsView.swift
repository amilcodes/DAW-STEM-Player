import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.instrumentOrange).frame(width: 2, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("sp–4").font(.instrument(16, weight: .medium))
                    Text("local performance and decoding")
                        .font(.instrument(9, weight: .regular))
                        .foregroundStyle(Color.instrumentTextSecondary)
                }
            }

            Rectangle().fill(Color.instrumentLine).frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                Text("performance").font(.instrument(11, weight: .medium))
                Toggle("Trackpad haptic feedback", isOn: $app.hapticsEnabled)
                Toggle("Play the recorded drum pattern", isOn: $app.isPatternEnabled)
                Toggle(
                    "Quantize pads to system audio",
                    isOn: Binding(
                        get: { app.tempoSync.isEnabled },
                        set: { enabled in
                            if enabled != app.tempoSync.isEnabled { app.toggleSystemTempoSync() }
                        }
                    )
                )
                Text("System sync needs Screen & System Audio Recording access. Built-in or wired output gives the tightest timing; Bluetooth adds delay.")
                    .font(.instrument(9, weight: .regular))
                    .foregroundStyle(Color.instrumentTextSecondary)
                    .lineSpacing(2)
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("audio decoding").font(.instrument(11, weight: .medium))
                HStack(spacing: 8) {
                    HardwareLED(color: AudioImportService.locateFFmpeg() == nil ? .instrumentOrange : .instrumentGreen, isOn: true)
                    Text(AudioImportService.locateFFmpeg() == nil ? "FFmpeg fallback not found" : "FFmpeg fallback ready")
                        .font(.instrument(10, weight: .medium))
                }
                Text("AVFoundation handles common formats first. FFmpeg is only used when macOS cannot decode a file natively.")
                    .font(.instrument(9, weight: .regular))
                    .foregroundStyle(Color.instrumentTextSecondary)
                    .lineSpacing(2)
            }

            Spacer()
            Text("No account · no uploads · no telemetry")
                .font(.instrument(8, weight: .medium))
                .foregroundStyle(Color.instrumentTextSecondary)
        }
        .padding(24)
        .background(Color.instrumentSurface)
        .foregroundStyle(Color.instrumentInk)
    }
}
