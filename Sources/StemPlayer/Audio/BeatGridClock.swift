import Foundation

struct BeatGridClock: Equatable, Sendable {
    struct Phase: Equatable, Sendable {
        var beatPosition: Double
        var beatPhase: Double
        var subdivisionIndex: Int
        var subdivisionPhase: Double
    }

    var bpm: Double
    var beatReferenceTime: Double

    func phase(at time: Double, subdivision: Int = 4) -> Phase {
        let divisions = max(1, subdivision)
        let beatPosition = (time - beatReferenceTime) * max(0.001, bpm) / 60
        let gridPosition = beatPosition * Double(divisions)
        let gridStep = Int(floor(gridPosition))
        let wrappedIndex = ((gridStep % divisions) + divisions) % divisions
        return Phase(
            beatPosition: beatPosition,
            beatPhase: positiveFraction(beatPosition),
            subdivisionIndex: wrappedIndex,
            subdivisionPhase: positiveFraction(gridPosition)
        )
    }

    func nextBoundary(after time: Double, subdivision: Int = 4, minimumLeadTime: Double = 0) -> Double {
        let divisions = max(1, subdivision)
        let stepDuration = 60 / max(0.001, bpm) / Double(divisions)
        let elapsed = time + max(0, minimumLeadTime) - beatReferenceTime
        let step = ceil(elapsed / stepDuration)
        return max(time, beatReferenceTime + step * stepDuration)
    }

    func quantizedBeat(at time: Double, lengthInBeats: Double, subdivision: Int = 4) -> Double? {
        guard lengthInBeats > 0 else { return nil }
        let divisions = max(1, subdivision)
        let beat = phase(at: time, subdivision: divisions).beatPosition
        let quantized = (beat * Double(divisions)).rounded(.up) / Double(divisions)
        let wrapped = quantized.truncatingRemainder(dividingBy: lengthInBeats)
        return wrapped >= 0 ? wrapped : wrapped + lengthInBeats
    }

    private func positiveFraction(_ value: Double) -> Double {
        let fraction = value - floor(value)
        return fraction >= 0 ? fraction : fraction + 1
    }
}
