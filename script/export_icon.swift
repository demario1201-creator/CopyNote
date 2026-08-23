import AppKit
import Foundation

// 生成 CopyNote 应用图标 PNG（512x512），用于 README 展示
let size: CGFloat = 512
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// 圆角背景：暖黄便签纸
let corner = size * 0.185
let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04),
                           xRadius: corner, yRadius: corner)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 1.00, green: 0.93, blue: 0.58, alpha: 1),
    NSColor(calibratedRed: 0.98, green: 0.79, blue: 0.32, alpha: 1)
])
gradient?.draw(in: bgPath, angle: -45)

// 纸张折角（右上）
let foldSize = size * 0.18
let fold = NSBezierPath()
fold.move(to: NSPoint(x: rect.maxX - size * 0.04, y: rect.maxY - size * 0.04 - foldSize))
fold.line(to: NSPoint(x: rect.maxX - size * 0.04 - foldSize, y: rect.maxY - size * 0.04))
fold.line(to: NSPoint(x: rect.maxX - size * 0.04, y: rect.maxY - size * 0.04))
fold.close()
NSColor(calibratedRed: 0.90, green: 0.68, blue: 0.22, alpha: 1).setFill()
fold.fill()

// 剪贴板符号（居中）
let cbW = size * 0.42
let cbH = size * 0.52
let cbX = rect.midX - cbW / 2
let cbY = rect.midY - cbH / 2 - size * 0.02
let boardRect = NSRect(x: cbX, y: cbY, width: cbW, height: cbH)
let board = NSBezierPath(roundedRect: boardRect, xRadius: size * 0.04, yRadius: size * 0.04)
NSColor.white.withAlphaComponent(0.95).setFill()
board.fill()
NSColor(calibratedWhite: 0.55, alpha: 1).setStroke()
board.lineWidth = size * 0.012
board.stroke()

// 板上的夹子
let clipRect = NSRect(x: cbX + cbW * 0.28, y: cbY + cbH - size * 0.11,
                      width: cbW * 0.44, height: size * 0.18)
let clip = NSBezierPath(roundedRect: clipRect, xRadius: size * 0.025, yRadius: size * 0.025)
NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.95, alpha: 1).setFill()
clip.fill()
NSColor(calibratedWhite: 0.3, alpha: 1).setStroke()
clip.lineWidth = size * 0.008
clip.stroke()

// 三行文字
let lineStartX = cbX + cbW * 0.14
let topY = cbY + cbH * 0.70
for i in 0..<3 {
    let y = topY - CGFloat(i) * cbH * 0.16
    let w = cbW * (i == 2 ? 0.55 : (i == 1 ? 0.75 : 0.68))
    let line = NSBezierPath()
    line.move(to: NSPoint(x: lineStartX, y: y))
    line.line(to: NSPoint(x: min(cbX + cbW * 0.86, lineStartX + w), y: y))
    line.lineWidth = size * 0.016
    line.lineCapStyle = .round
    NSColor(calibratedWhite: 0.35, alpha: 0.9).setStroke()
    line.stroke()
}

// 复制勾号徽章（右下）
let badgeSize = size * 0.22
let bx = rect.maxX - size * 0.11 - badgeSize
let by = rect.minY + size * 0.11
let badgeRect = NSRect(x: bx, y: by, width: badgeSize, height: badgeSize)
let badge = NSBezierPath(ovalIn: badgeRect)
NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.35, alpha: 1).setFill()
badge.fill()

let check = NSBezierPath()
check.move(to: NSPoint(x: bx + badgeSize * 0.28, y: by + badgeSize * 0.52))
check.line(to: NSPoint(x: bx + badgeSize * 0.46, y: by + badgeSize * 0.72))
check.line(to: NSPoint(x: bx + badgeSize * 0.75, y: by + badgeSize * 0.32))
check.lineWidth = badgeSize * 0.10
check.lineCapStyle = .round
check.lineJoinStyle = .round
NSColor.white.setStroke()
check.stroke()

image.unlockFocus()

// 保存为 PNG
let tiffData = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiffData)!
let pngData = rep.representation(using: .png, properties: [:])!

let outputURL = URL(fileURLWithPath: "docs/copynote-icon.png")
try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                          withIntermediateDirectories: true)
try pngData.write(to: outputURL)
print("Icon saved to \(outputURL.path) (\(pngData.count) bytes)")
