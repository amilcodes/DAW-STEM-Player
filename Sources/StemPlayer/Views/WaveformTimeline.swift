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

                Canvas { context, size in
                    let stemCount = max(1, app.project.stems.count)
                    let laneHeight = size.height / CGFloat(stemCount)
                    for lane in 1..<stemCount {
                        let y = CGFloat(lane) * laneHeight
                        var divider = Path(); divider.move(to: CGPoint(x: 0, y: y)); divider.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(divider, with: .color(.white.opacity(0.08)), lineWidth: 1)
                    }
                    for (index, stem) in app.project.stems.enumerated() {
                        guard let peaks = app.waveforms[stem.id], peaks.count > 1 else { continue }
                        let center = laneHeight * (CGFloat(index) + 0.5)
                        let amplitude = laneHeight * 0.32
                        var shape = Path()
                        for peakIndex in peaks.indices {
                            let x = CGFloat(peakIndex) / CGFloat(peaks.count - 1) * size.width
                            let value = CGFloat(peaks[peakIndex]) * amplitude
                            if peakIndex == 0 { shape.move(to: CGPoint(x: x, y: center - value)) }
                            else { shape.addLine(to: CGPoint(x: x, y: center - value)) }
                        }
                        for peakIndex in peaks.indices.reversed() {
                            let x = CGFloat(peakIndex) / CGFloat(peaks.count - 1) * size.width
                            shape.addLine(to: CGPoint(x: x, y: center + CGFloat(peaks[peakIndex]) * amplitude))
                        }
                        shape.closeSubpath()
                        context.fill(shape, with: .color(stem.role.color.opacity(0.7)))
                    }
                }
                .padding(.vertical, 15)

                if app.project.loop.isEnabled {
                    let start = proxy.size.width * app.project.loop.startSeconds / duration
                    let end = proxy.size.width * app.project.loop.endSeconds / duration
                    Rectangle().fill(Color.instrumentYellow.opacity(0.12)).frame(width: max(2, end - start))
                        .overlay(alignment: .top) { Rectangle().fill(Color.instrumentYellow).frame(height: 2) }.offset(x: start)
                }

                Rectangle().fill(Color.instrumentRaised).frame(width: 1).offset(x: max(0, min(proxy.size.width - 1, playheadX)))

                VStack {
                    HStack {
                        Text("POS  \(audio.currentTime.transportString)")
                        Spacer()
                        Text("LEN  \(app.project.durationSeconds.transportString)")
                    }
                    .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.52))
                    .padding(.horizontal, 9).padding(.top, 5)
                    Spacer()
                }
            }
            .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.85), lineWidth: 1))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                let ratio = max(0, min(1, gesture.location.x / max(1, proxy.size.width)))
                audio.seek(to: ratio * duration)
            })
        }
        .frame(minHeight: 86, idealHeight: 102, maxHeight: 112)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Song waveform")
        .accessibilityValue("Playhead at \(audio.currentTime.transportString)")
    }
}
