import SwiftUI

struct WaveformTimeline: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var audio: AudioEngineController

    var body: some View {
        GeometryReader { proxy in
            let duration = max(0.001, app.project.durationSeconds)
            let playheadX = proxy.size.width * audio.currentTime / duration
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.instrumentDisplay)

                if app.project.stems.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Text(app.project.title.lowercased())
                                .font(.instrument(6.5, weight: .medium))
                            Spacer()
                            HardwareLED(color: app.tempoSync.isLocked ? .instrumentGreen : .instrumentOrange, isOn: true, size: 3)
                        }
                        Spacer()
                        HStack {
                            Text(app.tempoSync.isEnabled ? app.tempoSync.displayText : "insert audio")
                                .font(.instrument(7, weight: .regular))
                                .foregroundStyle(app.tempoSync.isLocked ? Color.instrumentGreen : Color.instrumentRaised.opacity(0.72))
                            Spacer()
                            Text(app.tempoSync.isLocked
                                 ? String(format: "%.1f", app.tempoSync.bpm ?? 0)
                                 : "44.1 / 32")
                                .font(.instrumentNumber(5.5, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.25))
                        }
                    }
                    .foregroundStyle(Color.instrumentRaised.opacity(0.72))
                    .padding(7)
                } else {
                    Canvas { context, size in
                        let stemCount = max(1, app.project.stems.count)
                        let laneHeight = size.height / CGFloat(stemCount)
                        for (index, stem) in app.project.stems.enumerated() {
                            guard let peaks = app.waveforms[stem.id], peaks.count > 1 else { continue }
                            let center = laneHeight * (CGFloat(index) + 0.5)
                            let amplitude = laneHeight * 0.32
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
                            let laneColor = app.selectedStemID == stem.id
                                ? Color.instrumentOrange.opacity(0.82)
                                : Color.instrumentRaised.opacity(0.16)
                            context.fill(shape, with: .color(laneColor))
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.top, 17)
                    .padding(.bottom, 14)
                    .opacity(app.tempoSync.isEnabled ? 0.14 : 1)

                    if app.project.loop.isEnabled {
                        let start = proxy.size.width * app.project.loop.startSeconds / duration
                        let end = proxy.size.width * app.project.loop.endSeconds / duration
                        Rectangle()
                            .fill(Color.instrumentOrange.opacity(0.08))
                            .frame(width: max(1, end - start))
                            .offset(x: start)
                    }

                    Rectangle()
                        .fill(Color.instrumentRaised.opacity(0.82))
                        .frame(width: 0.7, height: 28)
                        .offset(x: max(0, min(proxy.size.width - 1, playheadX)))
                        .opacity(app.tempoSync.isEnabled ? 0.18 : 1)

                    VStack(spacing: 0) {
                        HStack(spacing: 5) {
                            Text(app.project.title.lowercased())
                                .font(.instrument(6.5, weight: .medium))
                                .lineLimit(1)
                            HardwareLED(
                                color: app.tempoSync.isLocked ? .instrumentGreen : (audio.isPlaying ? .instrumentGreen : .instrumentOrange),
                                isOn: true,
                                size: 3
                            )
                        Spacer()
                            Text(app.tempoSync.isLocked
                                 ? String(format: "%.1f", app.tempoSync.bpm ?? 0)
                                 : String(format: "%02d", app.project.stems.count))
                                .font(.instrumentNumber(5.5, weight: .medium))
                        }
                        Spacer()
                        HStack {
                            Text(audio.currentTime.transportString)
                                .foregroundStyle(Color.instrumentOrange)
                            Spacer()
                            Text(app.project.durationSeconds.transportString)
                        }
                        .font(.instrumentNumber(5.5, weight: .medium))
                    }
                    .foregroundStyle(Color.white.opacity(0.42))
                    .padding(7)
                }

                if app.tempoSync.isEnabled {
                    SyncPulseTrace(sync: app.tempoSync)
                        .padding(.horizontal, 7)
                        .padding(.top, 18)
                        .padding(.bottom, 13)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.instrumentInk.opacity(0.5), lineWidth: 0.7))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                guard !app.project.stems.isEmpty else { return }
                let ratio = max(0, min(1, gesture.location.x / max(1, proxy.size.width)))
                audio.seek(to: ratio * duration)
            })
        }
        .frame(height: 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Song waveform")
        .accessibilityValue(
            app.tempoSync.isLocked
                ? String(format: "System audio locked at %.1f BPM", app.tempoSync.bpm ?? 0)
                : "Playhead at \(audio.currentTime.transportString)"
        )
    }

}
