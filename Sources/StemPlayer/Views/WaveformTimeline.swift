import SwiftUI

struct WaveformTimeline: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var audio: AudioEngineController

    var body: some View {
        GeometryReader { proxy in
            let duration = max(0.001, app.project.durationSeconds)
            let playheadX = proxy.size.width * audio.currentTime / duration
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.instrumentDisplay)

                if app.project.stems.isEmpty {
                    HStack(spacing: 6) {
                        HardwareLED(color: .instrumentOrange, isOn: true, size: 4)
                        Text("NO MEDIA")
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.instrumentYellow)
                        Spacer()
                        Text("44.1K / 32")
                            .font(.system(size: 5.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.25))
                    }
                    .padding(.horizontal, 7)
                } else {
                    Canvas { context, size in
                        let stemCount = max(1, app.project.stems.count)
                        let laneHeight = size.height / CGFloat(stemCount)
                        for (index, stem) in app.project.stems.enumerated() {
                            guard let peaks = app.waveforms[stem.id], peaks.count > 1 else { continue }
                            let center = laneHeight * (CGFloat(index) + 0.5)
                            let amplitude = laneHeight * 0.33
                            var shape = Path()
                            for peakIndex in peaks.indices {
                                let x = CGFloat(peakIndex) / CGFloat(peaks.count - 1) * size.width
                                let y = center - CGFloat(peaks[peakIndex]) * amplitude
                                if peakIndex == 0 { shape.move(to: CGPoint(x: x, y: y)) }
                                else { shape.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            for peakIndex in peaks.indices.reversed() {
                                let x = CGFloat(peakIndex) / CGFloat(peaks.count - 1) * size.width
                                shape.addLine(to: CGPoint(x: x, y: center + CGFloat(peaks[peakIndex]) * amplitude))
                            }
                            shape.closeSubpath()
                            context.fill(shape, with: .color(stem.role.color.opacity(0.72)))
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 5)

                    if app.project.loop.isEnabled {
                        let start = proxy.size.width * app.project.loop.startSeconds / duration
                        let end = proxy.size.width * app.project.loop.endSeconds / duration
                        Rectangle()
                            .fill(Color.instrumentYellow.opacity(0.11))
                            .frame(width: max(1, end - start))
                            .overlay(alignment: .top) { Rectangle().fill(Color.instrumentYellow).frame(height: 1) }
                            .offset(x: start)
                    }

                    Rectangle()
                        .fill(Color.instrumentRaised)
                        .frame(width: 1)
                        .offset(x: max(0, min(proxy.size.width - 1, playheadX)))

                    VStack(spacing: 0) {
                        HStack {
                            Text(audio.currentTime.transportString)
                                .foregroundStyle(Color.instrumentYellow)
                            Spacer()
                            Text(app.project.durationSeconds.transportString)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            HardwareLED(color: audio.isPlaying ? .instrumentGreen : .instrumentOrange, isOn: true, size: 3)
                            Text(statusText)
                            Spacer()
                            Text(app.mode.shortName.uppercased())
                        }
                    }
                    .font(.system(size: 5.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                }
            }
            .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.85), lineWidth: 1))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                guard !app.project.stems.isEmpty else { return }
                let ratio = max(0, min(1, gesture.location.x / max(1, proxy.size.width)))
                audio.seek(to: ratio * duration)
            })
        }
        .frame(height: 42)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Song waveform")
        .accessibilityValue("Playhead at \(audio.currentTime.transportString)")
    }

    private var statusText: String {
        switch app.separator.state {
        case .preparing: "PREP"
        case .running(let progress, _): "SPLIT \(Int(progress * 100))%"
        case .failed: "SPLIT ERR"
        default: audio.isPlaying ? "RUN" : "READY"
        }
    }
}
