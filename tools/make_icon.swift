#!/usr/bin/env swift
import AppKit
import Foundation

let emoji = "⏰"
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let pixels: CGFloat = 1024

let canvas = NSImage(size: NSSize(width: pixels, height: pixels))
canvas.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    FileHandle.standardError.write(Data("No graphics context\n".utf8))
    exit(1)
}
ctx.setShouldAntialias(true)
ctx.setShouldSmoothFonts(true)
ctx.interpolationQuality = .high

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()

let inset: CGFloat = pixels * 0.08
let radius: CGFloat = pixels * 0.22
let bgRect = NSRect(x: inset, y: inset, width: pixels - 2 * inset, height: pixels - 2 * inset)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)

if let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.95, green: 0.18, blue: 0.25, alpha: 1.0),
    NSColor(srgbRed: 0.99, green: 0.48, blue: 0.10, alpha: 1.0)
]) {
    gradient.draw(in: bgPath, angle: 135)
} else {
    NSColor.systemRed.setFill()
    bgPath.fill()
}

let fontSize = pixels * 0.62
let font = NSFont.systemFont(ofSize: fontSize)
let attrs: [NSAttributedString.Key: Any] = [.font: font]
let str = NSAttributedString(string: emoji, attributes: attrs)
let strSize = str.size()
let drawPoint = NSPoint(
    x: (pixels - strSize.width) / 2,
    y: (pixels - strSize.height) / 2 - pixels * 0.02
)
str.draw(at: drawPoint)

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to encode PNG\n".utf8))
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath) (\(png.count) bytes)")
