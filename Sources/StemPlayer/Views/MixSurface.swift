import SwiftUI

struct MixSurface: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var audio: AudioEngineController

    private var slotCount: Int { max(4, app.project.stems.count) }

    var body: some View {
        ZStack {
            Color.instrumentDisplay
            PanelScrews()
            VStack(spacing: 0) {
                header
                Rectangle().fill(Color.white.opacity(0.18)).frame(height: 1)
                GeometryReader { proxy in
                    let width = max(116, (proxy.size.width - CGFloat(slotCount - 1)) / CGFloat(slotCount))
                    ScrollView(.horizontal) {
                        HStack(spacing: 1) {
                            ForEach(0..<slotCount, id: \.self) { index in
                                if app.project.stems.indices.contains(index) {
                                    let stem = app.project.stems[index]
                                    StemChannelStrip(index: index, stem: stem, meter: audio.meters[stem.id] ?? .init()).frame(width: width)
                                } else {
                                    EmptyChannelStrip(index: index).frame(width: width)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                transportRail
            }
            .padding(14)
        }
        .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.9), lineWidth: 1))
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("STEM MIXER / FOUR PART DIRECT CONTROL")
                    .font(.system(size: 10, weight: .black, design: .monospaced)).tracking(0.5).foregroundStyle(Color.white.opacity(0.84))
                Text("DRAG LEVEL  ·  DOUBLE-CLICK FADER FOR 0 DB  ·  SELECT 1–4")
                    .font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.38))
            }
            Spacer()
            HStack(spacing: 9) {
                Text("OUT").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.45))
                LevelMeter(value: audio.meters.values.map(\.peak).max() ?? 0, tint: .instrumentGreen, vertical: false).frame(width: 92, height: 11)
            }
        }
        .frame(height: 40).padding(.horizontal, 10)
    }

    private var transportRail: some View {
        HStack(spacing: 14) {
            Button("−5") { audio.skip(seconds: -5) }.buttonStyle(InstrumentButtonStyle(compact: true)).help("Back 5 seconds — J")
            Button("+5") { audio.skip(seconds: 5) }.buttonStyle(InstrumentButtonStyle(compact: true)).help("Forward 5 seconds — L")
            Spacer()
            VStack(spacing: 2) {
                Text(audio.currentTime.transportString).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentYellow)
                Text(audio.isPlaying ? "PLAYING" : "STOPPED").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.38))
            }
            .frame(width: 106, alignment: .leading)
            StemTransportControl()
            Spacer()
            Button(app.project.loop.isEnabled ? "LOOP ON" : "LOOP") { app.toggleLoop() }
                .buttonStyle(InstrumentButtonStyle(accent: .instrumentYellow, isLatched: app.project.loop.isEnabled, compact: true))
            Button("IN") { app.setLoopIn() }.buttonStyle(InstrumentButtonStyle(compact: true))
            Button("OUT") { app.setLoopOut() }.buttonStyle(InstrumentButtonStyle(compact: true))
        }
        .padding(.horizontal, 11).frame(height: 92)
        .background(Color.white.opacity(0.035))
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.17)).frame(height: 1) }
    }
}

private struct StemChannelStrip: View {
    @EnvironmentObject private var app: AppState
    let index: Int
    let stem: StemModel
    let meter: AudioEngineController.Meter

    private var isSelected: Bool { app.selectedStemID == stem.id }

    var body: some View {
        VStack(spacing: 10) {
            Button { app.selectStem(stem.id) } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(String(format: "CH %02d", index + 1)); Spacer(); HardwareLED(color: stem.role.color, isOn: isSelected)
                    }
                    .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.42))
                    Rectangle().fill(stem.role.color).frame(height: 5)
                    Text(stem.name.uppercased()).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(Color.white.opacity(0.86)).lineLimit(1)
                    Text(stem.role.displayName.uppercased()).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(stem.role.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack(spacing: 11) {
                LevelMeter(value: meter.peak, tint: stem.role.color).frame(width: 9)
                PhysicalFader(value: Binding(get: { stem.gainDB }, set: { value in app.updateStem(stem.id) { $0.gainDB = value } }), tint: stem.role.color)
            }
            .frame(maxHeight: .infinity)

            Text("\(stem.gainDB.decibelString) DB").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(stem.role.color)
            HStack(spacing: 7) {
                Button("M") { app.updateStem(stem.id) { $0.isMuted.toggle() } }
                    .buttonStyle(InstrumentButtonStyle(accent: stem.role.color, isLatched: stem.isMuted, compact: true))
                Button("S") { app.updateStem(stem.id) { $0.isSolo.toggle() } }
                    .buttonStyle(InstrumentButtonStyle(accent: stem.role.color, isLatched: stem.isSolo, compact: true))
            }
            Text("MUTE  /  SOLO").font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.3))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(isSelected ? Color.white.opacity(0.075) : Color.white.opacity(0.025))
        .overlay(alignment: .leading) { Rectangle().fill(isSelected ? stem.role.color : Color.white.opacity(0.1)).frame(width: isSelected ? 3 : 1) }
        .overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1) }
        .contentShape(Rectangle()).onTapGesture { app.selectStem(stem.id) }
        .accessibilityElement(children: .contain).accessibilityLabel("\(stem.name) stem")
    }
}

private struct EmptyChannelStrip: View {
    let index: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack { Text(String(format: "CH %02d", index + 1)); Spacer(); HardwareLED(color: Color.padColor(index), isOn: false) }
                .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.28))
            Rectangle().fill(Color.padColor(index).opacity(0.26)).frame(height: 5)
            Text("EMPTY").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.24))
            Spacer()
            Rectangle().fill(Color.white.opacity(0.09)).frame(width: 5).overlay(alignment: .bottom) { Rectangle().fill(Color.padColor(index).opacity(0.2)).frame(width: 2, height: 44) }
            Spacer()
            Text("— DB").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.18))
            HStack(spacing: 7) { KeyCap(text: "M"); KeyCap(text: "S") }.opacity(0.26)
            Text("AVAILABLE BAY").font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.2))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1) }
    }
}

private struct StemTransportControl: View {
    @EnvironmentObject private var audio: AudioEngineController

    var body: some View {
        Button { audio.togglePlayback() } label: {
            ZStack {
                Circle().fill(Color.instrumentSurface).overlay(Circle().stroke(Color.instrumentRaised.opacity(0.58), lineWidth: 1))
                ForEach(0..<4, id: \.self) { index in
                    Capsule().fill(Color.padColor(index)).frame(width: 7, height: 20).offset(y: -26).rotationEffect(.degrees(Double(index) * 90))
                }
                Circle().fill(Color.instrumentRaised).overlay(Circle().stroke(Color.instrumentInk.opacity(0.72), lineWidth: 1)).frame(width: 41, height: 41)
                Text(audio.isPlaying ? "Ⅱ" : "▶").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(Color.instrumentInk).offset(x: audio.isPlaying ? 0 : 1)
            }
            .frame(width: 76, height: 76)
        }
        .buttonStyle(.plain).help("Play or pause — Space")
    }
}
