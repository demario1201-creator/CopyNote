import AppKit
import Foundation

// 生成新版 statusbar 模板图标（单色「文档+折角+三行文本」符号，与 AppIcon 主视觉一致）。
// 输出 Resources/statusbar-16.png / statusbar-16@2x.png / statusbar-18.png / statusbar-18@2x.png
// 注意：菜单栏模板图只认 alpha 通道 —— 黑色实心 + 透明挖洞，模板化后跟随系统菜单色。

let outputDir = "Resources"

func drawDocumentGlyph(pixel size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    guard let cg = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }

    let m = size * 0.10        // 边距
    let w = size - m * 2
    let h = size - m * 2
    let x = m, y = m
    let fold = w * 0.30        // 折角宽度
    let r = size * 0.07        // 文档圆角

    // 文档主体（右上角切出折角斜边）
    let body = NSBezierPath()
    body.move(to: NSPoint(x: x + r, y: y))
    body.line(to: NSPoint(x: x + w - fold, y: y))
    body.line(to: NSPoint(x: x + w, y: y + fold))
    body.line(to: NSPoint(x: x + w, y: y + h - r))
    body.appendArc(withCenter: NSPoint(x: x + w - r, y: y + h - r), radius: r, startAngle: 0, endAngle: 90)
    body.line(to: NSPoint(x: x + r, y: y + h))
    body.appendArc(withCenter: NSPoint(x: x + r, y: y + h - r), radius: r, startAngle: 90, endAngle: 180)
    body.line(to: NSPoint(x: x, y: y + r))
    body.appendArc(withCenter: NSPoint(x: x + r, y: y + r), radius: r, startAngle: 180, endAngle: 270)
    body.close()

    NSColor.black.setFill()
    body.fill()

    // 挖洞：折角三角 + 三条文本线（alpha → 0）
    let holes = NSBezierPath()
    let foldTri = NSBezierPath()
    foldTri.move(to: NSPoint(x: x + w - fold, y: y))
    foldTri.line(to: NSPoint(x: x + w, y: y + fold))
    foldTri.line(to: NSPoint(x: x + w, y: y))
    foldTri.close()
    holes.append(foldTri)

    let lineH = max(size * 0.05, 1.0)   // 线高
    let gap = h * 0.20
    let topY = y + h * 0.60
    let lx = x + w * 0.14
    let widths: [CGFloat] = [0.72, 0.55, 0.38]
    for (i, fw) in widths.enumerated() {
        let lw = w * fw
        let ly = topY - CGFloat(i) * gap
        let line = NSBezierPath(roundedRect: NSRect(x: lx, y: ly, width: lw, height: lineH),
                                xRadius: lineH / 2, yRadius: lineH / 2)
        holes.append(line)
    }

    cg.setBlendMode(.clear)
    holes.fill()
    cg.setBlendMode(.normal)

    img.unlockFocus()
    return img
}

let variants: [(name: String, px: CGFloat)] = [
    ("statusbar-16", 16),
    ("statusbar-16@2x", 32),
    ("statusbar-18", 18),
    ("statusbar-18@2x", 36),
]

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for v in variants {
    let image = drawDocumentGlyph(pixel: v.px)
    let tiff = image.tiffRepresentation!
    let rep = NSBitmapImageRep(data: tiff)!
    let png = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: "\(outputDir)/\(v.name).png")
    try png.write(to: url)
    print("Saved \(url.path) (\(v.px)x\(Int(v.px))px, \(png.count) bytes)")
}
