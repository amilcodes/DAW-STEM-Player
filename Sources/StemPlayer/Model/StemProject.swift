import Foundation
import SwiftUI

enum StemRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case drums
    case vocals
    case instruments
    case bass
    case mix
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .drums: "Drums"
        case .vocals: "Vocals"
        case .instruments: "Other"
        case .bass: "Bass"
        case .mix: "Full Mix"
        case .custom: "Stem"
        }
    }

    var systemImage: String {
        switch self {
        case .drums: "circle.grid.cross"
        case .vocals: "waveform"
        case .instruments: "pianokeys"
        case .bass: "waveform.path"
        case .mix: "waveform.badge.magnifyingglass"
        case .custom: "slider.horizontal.3"
        }
    }

    var color: Color {
        switch self {
        case .drums: .instrumentOrange
        case .vocals: .instrumentYellow
        case .instruments: .instrumentGreen
        case .bass: .instrumentBlue
        case .mix: .instrumentOrange
        case .custom: .instrumentBlue
        }
    }

    static func infer(from filename: String) -> StemRole {
        let name = filename.lowercased()
        if name.contains("drum") || name.contains("perc") { return .drums }
        if name.contains("vocal") || name.contains("voice") || name.contains("vox") { return .vocals }
        if name.contains("bass") { return .bass }
        if name.contains("instrument") || name.contains("other") || name.contains("music") ||
            name.contains("guitar") || name.contains("piano") || name.contains("keys") {
            return .instruments
        }
        return .custom
    }
}

struct StemModel: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var role: StemRole
    var name: String
    var relativePath: String
    var sourcePath: String?
    var gainDB: Float
    var pan: Float
    var tone: Float
    var isMuted: Bool
    var isSolo: Bool

    init(
        id: UUID = UUID(),
        role: StemRole,
        name: String? = nil,
        relativePath: String,
        sourcePath: String? = nil,
        gainDB: Float = 0,
        pan: Float = 0,
        tone: Float = 0,
        isMuted: Bool = false,
        isSolo: Bool = false
    ) {
        self.id = id
        self.role = role
        self.name = name ?? role.displayName
        self.relativePath = relativePath
        self.sourcePath = sourcePath
        self.gainDB = gainDB
        self.pan = pan
        self.tone = tone
        self.isMuted = isMuted
        self.isSolo = isSolo
    }
}

enum PadTriggerMode: String, Codable, Sendable {
    case oneShot
    case gate
}

struct PadModel: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var index: Int
    var name: String
    var relativePath: String?
    var sourcePath: String?
    var gainDB: Float
    var pan: Float
    var pitchSemitones: Float
    var chokeGroup: Int?
    var triggerMode: PadTriggerMode

    init(
        id: UUID = UUID(),
        index: Int,
        name: String,
        relativePath: String? = nil,
        sourcePath: String? = nil,
        gainDB: Float = 0,
        pan: Float = 0,
        pitchSemitones: Float = 0,
        chokeGroup: Int? = nil,
        triggerMode: PadTriggerMode = .oneShot
    ) {
        self.id = id
        self.index = index
        self.name = name
        self.relativePath = relativePath
        self.sourcePath = sourcePath
        self.gainDB = gainDB
        self.pan = pan
        self.pitchSemitones = pitchSemitones
        self.chokeGroup = chokeGroup
        self.triggerMode = triggerMode
    }
}

struct PatternEvent: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var padIndex: Int
    var beat: Double
    var velocity: Float

    init(id: UUID = UUID(), padIndex: Int, beat: Double, velocity: Float = 0.86) {
        self.id = id
        self.padIndex = padIndex
        self.beat = beat
        self.velocity = velocity
    }
}

struct DrumPattern: Codable, Hashable, Sendable {
    var bpm: Double = 100
    var bars: Int = 1
    var swing: Double = 0
    var quantization: Double = 1
    var events: [PatternEvent] = []

    var lengthInBeats: Double { Double(max(1, bars) * 4) }
}

struct LoopRange: Codable, Hashable, Sendable {
    var isEnabled: Bool = false
    var startSeconds: Double = 0
    var endSeconds: Double = 8

    var duration: Double { max(0.05, endSeconds - startSeconds) }
}

struct StemProject: Identifiable, Codable, Sendable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var id: UUID
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    var sampleRate: Double
    var durationSeconds: Double
    var stems: [StemModel]
    var pads: [PadModel]
    var pattern: DrumPattern
    var loop: LoopRange

    init(
        id: UUID = UUID(),
        title: String = "Untitled Session",
        sampleRate: Double = 44_100,
        durationSeconds: Double = 0,
        stems: [StemModel] = [],
        pads: [PadModel] = StemProject.defaultPads,
        pattern: DrumPattern = DrumPattern(),
        loop: LoopRange = LoopRange()
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.sampleRate = sampleRate
        self.durationSeconds = durationSeconds
        self.stems = stems
        self.pads = pads
        self.pattern = pattern
        self.loop = loop
    }

    static let defaultPads: [PadModel] = {
        let names = [
            "Kick", "Snare", "Closed Hat", "Open Hat",
            "Low Tom", "High Tom", "Clap", "Rim",
            "Sub", "Perc A", "Perc B", "Noise"
        ]
        return names.enumerated().map { index, name in
            PadModel(index: index, name: name, chokeGroup: index == 2 || index == 3 ? 1 : nil)
        }
    }()
}

enum WorkspaceMode: String, CaseIterable, Identifiable {
    case mix = "Mix"
    case pads = "Pads"
    case pattern = "Pattern"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .mix: "slider.horizontal.3"
        case .pads: "square.grid.3x3.fill"
        case .pattern: "timeline.selection"
        }
    }
}
