import SwiftUI

struct SyncPulseTrace: View {
    @ObservedObject var sync: SystemAudioTempoSync

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 48)) { _ in
            Canvas { context, size in
                if let phase = sync.phaseSnapshot(subdivision: 4) {
                    drawLockedTrace(context: &context, size: size, phase: phase)
                } else {
                    drawListeningTrace(context: &context, size: size)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func drawLockedTrace(
        context: inout GraphicsContext,
        size: CGSize,
        phase: SystemAudioTempoSync.PhaseSnapshot
    ) {
        let baseline = size.height * 0.59
        var basePath = Path()
        basePath.move(to: CGPoint(x: 0, y: baseline))
        basePath.addLine(to: CGPoint(x: size.width, y: baseline))
        context.stroke(basePath, with: .color(Color.white.opacity(0.055)), lineWidth: 0.5)

        let trace = pulsePath(size: size, baseline: baseline, beatPosition: phase.beatPosition)
        context.stroke(
            trace,
            with: .linearGradient(
                Gradient(colors: [
                    Color.instrumentGreen.opacity(0.16),
                    Color.instrumentGreen.opacity(0.72),
                    Color.instrumentGreen.opacity(0.94)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: 0)
            ),
            lineWidth: 0.85
        )

        let flash = max(0, 1 - phase.beatPhase / 0.12)
        let gridFlash = max(0, 1 - phase.subdivisionPhase / 0.22)
        let dotSize = 1.5 + CGFloat(gridFlash) * 1.2 + CGFloat(flash) * 2.2
        context.fill(
            Path(ellipseIn: CGRect(
                x: size.width - dotSize,
                y: baseline - dotSize / 2,
                width: dotSize,
                height: dotSize
            )),
            with: .color(Color.instrumentGreen.opacity(0.48 + gridFlash * 0.24 + flash * 0.28))
        )

        var sweep = Path()
        sweep.move(to: CGPoint(x: size.width - 0.5, y: 2))
        sweep.addLine(to: CGPoint(x: size.width - 0.5, y: size.height - 2))
        context.stroke(
            sweep,
            with: .color(Color.instrumentGreen.opacity(0.18 + gridFlash * 0.18 + flash * 0.24)),
            lineWidth: 0.5
        )

        let markerGap: CGFloat = 6
        let markerStart = size.width - markerGap * 4 - 3
        for index in 0..<4 {
            let isCurrent = index == phase.subdivisionIndex
            let attack = isCurrent ? max(0, 1 - phase.subdivisionPhase * 1.8) : 0
            let height: CGFloat = index == 0 ? 4 : 2.5
            let marker = CGRect(
                x: markerStart + CGFloat(index) * markerGap,
                y: 1,
                width: 1.8,
                height: height
            )
            context.fill(
                Path(roundedRect: marker, cornerRadius: 0.5),
                with: .color(Color.instrumentGreen.opacity(isCurrent ? 0.58 + attack * 0.42 : 0.28))
            )
        }
    }

    private func drawListeningTrace(context: inout GraphicsContext, size: CGSize) {
        let baseline = size.height * 0.59
        var path = Path()
        let dashWidth: CGFloat = 3
        var x: CGFloat = 0
        while x < size.width {
            path.move(to: CGPoint(x: x, y: baseline))
            path.addLine(to: CGPoint(x: min(size.width, x + dashWidth), y: baseline))
            x += dashWidth * 2.5
        }
        context.stroke(path, with: .color(Color.white.opacity(0.09)), lineWidth: 0.5)

        let scanDuration = 1.4
        let scanPhase = ProcessInfo.processInfo.systemUptime.truncatingRemainder(dividingBy: scanDuration) / scanDuration
        let scanX = CGFloat(scanPhase) * size.width
        var scan = Path()
        scan.move(to: CGPoint(x: max(0, scanX - 9), y: baseline))
        scan.addLine(to: CGPoint(x: scanX, y: baseline))
        context.stroke(scan, with: .color(Color.instrumentGreen.opacity(0.44)), lineWidth: 0.8)
        context.fill(
            Path(ellipseIn: CGRect(x: scanX - 1, y: baseline - 1, width: 2, height: 2)),
            with: .color(Color.instrumentGreen.opacity(0.7))
        )
    }

    private func pulsePath(size: CGSize, baseline: CGFloat, beatPosition: Double) -> Path {
        let historyInBeats = 4.0
        let amplitude = size.height * 0.38
        let samples = max(2, Int(size.width.rounded(.up)))
        var path = Path()

        for sample in 0...samples {
            let fraction = Double(sample) / Double(samples)
            let beat = beatPosition - historyInBeats * (1 - fraction)
            let x = CGFloat(fraction) * size.width
            let y = baseline - CGFloat(pulseAmplitude(at: beat)) * amplitude
            if sample == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }

    private func pulseAmplitude(at beatPosition: Double) -> Double {
        var distance = beatPosition - beatPosition.rounded()
        if distance < -0.5 { distance += 1 }
        if distance > 0.5 { distance -= 1 }

        let keyframes: [(Double, Double)] = [
            (-0.12, 0), (-0.075, 0), (-0.052, -0.13), (-0.03, 0.28),
            (-0.012, -0.05), (0, 1), (0.022, -0.62), (0.052, 0.2), (0.09, 0)
        ]
        guard distance >= keyframes[0].0, distance <= keyframes[keyframes.count - 1].0 else { return 0 }
        for index in 1..<keyframes.count where distance <= keyframes[index].0 {
            let previous = keyframes[index - 1]
            let next = keyframes[index]
            let amount = (distance - previous.0) / (next.0 - previous.0)
            return previous.1 + (next.1 - previous.1) * amount
        }
        return 0
    }
}
