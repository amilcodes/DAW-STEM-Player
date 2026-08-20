import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<4, id: \.self) { index in
                        Rectangle().fill(Color.padColor(index)).frame(width: 3, height: CGFloat(11 + index * 3))
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("sp–4 settings").font(.system(size: 16, weight: .semibold))
                    Text("local performance and decoding")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Color.instrumentTextSecondary)
                }
            }

            Rectangle().fill(Color.instrumentLine).frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                Text("Performance").font(.system(size: 11, weight: .semibold))
                Toggle("Trackpad haptic feedback", isOn: $app.hapticsEnabled)
                Toggle("Play the recorded drum pattern", isOn: $app.isPatternEnabled)
                Text("Built-in speakers, wired headphones, or an audio interface give the lowest pad latency. Bluetooth adds output delay.")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Color.instrumentTextSecondary)
                    .lineSpacing(2)
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("Audio decoding").font(.system(size: 11, weight: .semibold))
                HStack(spacing: 8) {
                    HardwareLED(color: AudioImportService.locateFFmpeg() == nil ? .instrumentOrange : .instrumentGreen, isOn: true)
                    Text(AudioImportService.locateFFmpeg() == nil ? "FFmpeg fallback not found" : "FFmpeg fallback ready")
                        .font(.system(size: 10, weight: .medium))
                }
                Text("AVFoundation handles common formats first. FFmpeg is only used when macOS cannot decode a file natively.")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Color.instrumentTextSecondary)
                    .lineSpacing(2)
            }

            Spacer()
            Text("No account · no uploads · no telemetry")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Color.instrumentTextSecondary)
        }
        .padding(24)
        .background(Color.instrumentSurface)
        .foregroundStyle(Color.instrumentInk)
    }
}
