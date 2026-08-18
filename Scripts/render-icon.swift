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
let ink = NSColor(red: 0.106, green: 0.110, blue: 0.102, alpha: 1)
let enclosure = NSColor(red: 0.710, green: 0.694, blue: 0.647, alpha: 1)
let face = NSColor(red: 0.831, green: 0.812, blue: 0.753, alpha: 1)
let raised = NSColor(red: 0.925, green: 0.906, blue: 0.847, alpha: 1)
let colors = [
    NSColor(red: 0.937, green: 0.306, blue: 0.122, alpha: 1),
    NSColor(red: 0.953, green: 0.729, blue: 0.125, alpha: 1),
    NSColor(red: 0.290, green: 0.631, blue: 0.349, alpha: 1),
    NSColor(red: 0.161, green: 0.427, blue: 0.729, alpha: 1)
]

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

    let border = NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 185, yRadius: 185)
    stroke(border, ink, width: 18)

    for point in [NSPoint(x: 104, y: 104), NSPoint(x: 920, y: 104), NSPoint(x: 104, y: 920), NSPoint(x: 920, y: 920)] {
        fill(NSBezierPath(ovalIn: NSRect(x: point.x - 18, y: point.y - 18, width: 36, height: 36)), ink.withAlphaComponent(0.42))
    }

    let body = NSBezierPath(ovalIn: NSRect(x: 186, y: 186, width: 652, height: 652))
    fill(body, face)
    stroke(body, ink, width: 18)

    let arms = [
        NSRect(x: 478, y: 592, width: 68, height: 214),
        NSRect(x: 592, y: 478, width: 214, height: 68),
        NSRect(x: 478, y: 218, width: 68, height: 214),
        NSRect(x: 218, y: 478, width: 214, height: 68)
    ]
    for (index, rect) in arms.enumerated() {
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        fill(path, colors[index])
        stroke(path, ink, width: 8)
    }

    let center = NSBezierPath(ovalIn: NSRect(x: 380, y: 380, width: 264, height: 264))
    fill(center, raised)
    stroke(center, ink, width: 16)

    let play = NSBezierPath()
    play.move(to: NSPoint(x: 482, y: 446))
    play.line(to: NSPoint(x: 598, y: 512))
    play.line(to: NSPoint(x: 482, y: 578))
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
