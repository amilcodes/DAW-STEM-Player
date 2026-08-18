import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                HStack(spacing: 2) { ForEach(0..<4, id: \.self) { index in Rectangle().fill(Color.padColor(index)).frame(width: 5, height: CGFloat(22 - index * 3)) } }
                VStack(alignment: .leading, spacing: 2) {
                    Text("SP–4 / SYSTEM SETTINGS").font(.system(size: 15, weight: .black, design: .monospaced))
                    Text("NATIVE AUDIO PERFORMANCE INSTRUMENT").instrumentLabel()
                }
            }
            Rectangle().fill(Color.instrumentLine).frame(height: 1)
            settingSection("PERFORMANCE") {
                Toggle("Trackpad haptic feedback", isOn: $app.hapticsEnabled)
                Toggle("Play recorded drum pattern", isOn: $app.isPatternEnabled)
                Text("For the lowest pad latency, use built-in speakers, wired headphones or an audio interface. Bluetooth adds output delay.")
                    .font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary)
            }
            settingSection("LOCAL DECODING") {
                HStack(spacing: 8) {
                    HardwareLED(color: AudioImportService.locateFFmpeg() == nil ? .instrumentOrange : .instrumentGreen, isOn: true)
                    Text(AudioImportService.locateFFmpeg() == nil ? "FFMPEG FALLBACK NOT FOUND" : "FFMPEG FALLBACK READY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                Text("AVFoundation handles common formats first. FFmpeg is only used when macOS cannot decode a file natively.")
                    .font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary)
            }
            Spacer()
            Text("LOCAL BY DESIGN  /  NO ACCOUNT  /  NO UPLOADS  /  NO TELEMETRY").instrumentLabel()
        }
        .padding(24).background(Color.instrumentSurface).foregroundStyle(Color.instrumentInk)
    }

    private func settingSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 8, weight: .black, design: .monospaced)).tracking(0.7)
                .foregroundStyle(Color.instrumentRaised).padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: 23, alignment: .leading).background(Color.instrumentInk)
            VStack(alignment: .leading, spacing: 9) { content() }.padding(.horizontal, 10)
        }
    }
}
