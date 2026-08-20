import AppKit
import Foundation

func bigEndianBytes(_ value: Int) -> [UInt8] {
    let number = UInt32(value)
    return [UInt8((number >> 24) & 0xff), UInt8((number >> 16) & 0xff), UInt8((number >> 8) & 0xff), UInt8(number & 0xff)]
}

if CommandLine.arguments.count >= 5, CommandLine.arguments[1] == "--icns" {
    let output = CommandLine.arguments[2]
    let entries = Array(CommandLine.arguments.dropFirst(3))
    guard entries.count.isMultiple(of: 2) else {
        fputs("icns entries must be type/path pairs\n", stderr)
        exit(2)
    }
    var chunks = Data()
    for index in stride(from: 0, to: entries.count, by: 2) {
        let type = entries[index]
        guard type.utf8.count == 4 else { fputs("invalid icns type\n", stderr); exit(2) }
        let png = try Data(contentsOf: URL(fileURLWithPath: entries[index + 1]))
        chunks.append(contentsOf: type.utf8)
        chunks.append(contentsOf: bigEndianBytes(png.count + 8))
        chunks.append(png)
    }
    var result = Data("icns".utf8)
    result.append(contentsOf: bigEndianBytes(chunks.count + 8))
    result.append(chunks)
    try result.write(to: URL(fileURLWithPath: output), options: .atomic)
    exit(0)
}

guard CommandLine.arguments.count == 2 else { fputs("usage: render-icon <output.png>\n", stderr); exit(2) }

let canvas = NSSize(width: 1024, height: 1024)
let ink = NSColor(red: 0.075, green: 0.078, blue: 0.075, alpha: 1)
let enclosure = NSColor(red: 0.76, green: 0.76, blue: 0.73, alpha: 1)
let face = NSColor(red: 0.91, green: 0.90, blue: 0.87, alpha: 1)
let raised = NSColor(red: 0.975, green: 0.97, blue: 0.945, alpha: 1)
let orange = NSColor(red: 0.92, green: 0.255, blue: 0.13, alpha: 1)

func fill(_ path: NSBezierPath, _ color: NSColor) {
    color.setFill()
    path.fill()
}

func stroke(_ path: NSBezierPath, _ color: NSColor, width: CGFloat) {
    color.setStroke()
    path.lineWidth = width
    path.stroke()
}

let image = NSImage(size: canvas, flipped: false) { _ in
    let outside = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), xRadius: 220, yRadius: 220)
    fill(outside, enclosure)

    let faceplate = NSBezierPath(roundedRect: NSRect(x: 34, y: 34, width: 956, height: 956), xRadius: 190, yRadius: 190)
    fill(faceplate, face)
    stroke(faceplate, ink.withAlphaComponent(0.38), width: 10)

    let screen = NSBezierPath(roundedRect: NSRect(x: 132, y: 650, width: 760, height: 190), xRadius: 34, yRadius: 34)
    fill(screen, ink)

    let waveform = NSBezierPath()
    waveform.move(to: NSPoint(x: 172, y: 738))
    let wavePoints: [CGFloat] = [0, 18, -9, 31, -20, 12, -5, 40, -14, 7, -27, 22, -8, 34, -17, 10, 0]
    for (index, value) in wavePoints.enumerated() {
        waveform.line(to: NSPoint(x: 172 + CGFloat(index) * 42, y: 738 + value))
    }
    stroke(waveform, orange, width: 10)

    fill(NSBezierPath(ovalIn: NSRect(x: 836, y: 786, width: 18, height: 18)), orange)

    let faderCenters: [CGFloat] = [250, 425, 600, 775]
    let handlePositions: [CGFloat] = [476, 410, 344, 446]
    for (index, centerX) in faderCenters.enumerated() {
        let rail = NSBezierPath(roundedRect: NSRect(x: centerX - 10, y: 220, width: 20, height: 350), xRadius: 10, yRadius: 10)
        fill(rail, ink)

        for tick in 0..<5 {
            let y = 236 + CGFloat(tick) * 76
            let left = NSBezierPath(rect: NSRect(x: centerX - 48, y: y, width: 22, height: 5))
            let right = NSBezierPath(rect: NSRect(x: centerX + 26, y: y, width: 22, height: 5))
            fill(left, ink.withAlphaComponent(0.22))
            fill(right, ink.withAlphaComponent(0.22))
        }

        let handle = NSBezierPath(roundedRect: NSRect(x: centerX - 48, y: handlePositions[index], width: 96, height: 52), xRadius: 8, yRadius: 8)
        fill(handle, raised)
        stroke(handle, ink.withAlphaComponent(0.48), width: 6)

        let mark = NSBezierPath(rect: NSRect(x: centerX - 32, y: handlePositions[index] + 24, width: 64, height: 5))
        fill(mark, index == 0 ? orange : ink.withAlphaComponent(0.44))
    }

    for x in [190, 310, 430] as [CGFloat] {
        let key = NSBezierPath(roundedRect: NSRect(x: x, y: 100, width: 90, height: 76), xRadius: 12, yRadius: 12)
        fill(key, raised)
        stroke(key, ink.withAlphaComponent(0.28), width: 5)
    }

    let playKey = NSBezierPath(roundedRect: NSRect(x: 710, y: 92, width: 132, height: 92), xRadius: 15, yRadius: 15)
    fill(playKey, orange)
    let play = NSBezierPath()
    play.move(to: NSPoint(x: 760, y: 116))
    play.line(to: NSPoint(x: 809, y: 138))
    play.line(to: NSPoint(x: 760, y: 160))
    play.close()
    fill(play, ink)
    return true
}

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("could not render icon\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
