import AppKit
import SwiftUI

/// 生成并缓存 CopyNote 自定义图标（纯代码绘制，无需外部资源文件）。
enum AppIconFactory {

    // MARK: - AppIcon (Dock / Finder)

    /// 生成 CopyNote App 图标（便签纸 + 剪贴板的叠层视觉，512×512）。
    static func makeAppIcon(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let ctx = NSGraphicsContext.current?.cgContext
        drawAppIcon(in: CGRect(x: 0, y: 0, width: size, height: size), ctx: ctx)
        image.unlockFocus()
        return image
    }

    private static func drawAppIcon(in rect: CGRect, ctx: CGContext?) {
        let size = rect.width
        // 圆角背景（macOS App Icon 风格的形状近似）
        let corner = size * 0.185
        let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04),
                                   xRadius: corner, yRadius: corner)
        // 渐变：暖黄色便签纸
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 1.00, green: 0.93, blue: 0.58, alpha: 1),
            NSColor(calibratedRed: 0.98, green: 0.79, blue: 0.32, alpha: 1)
        ])
        gradient?.draw(in: bgPath, angle: -45)
        // 顶部阴影
        NSColor.black.withAlphaComponent(0.08).setFill()
        let shadow = NSBezierPath(roundedRect: NSRect(
            x: rect.minX + size * 0.04,
            y: rect.minY + rect.height - size * 0.18,
            width: size * 0.92,
            height: size * 0.14
        ), xRadius: corner * 0.8, yRadius: corner * 0.8)
        shadow.fill()

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
        // 板身
        let boardRect = NSRect(x: cbX, y: cbY, width: cbW, height: cbH)
        let board = NSBezierPath(roundedRect: boardRect,
                                 xRadius: size * 0.04, yRadius: size * 0.04)
        NSColor.white.withAlphaComponent(0.95).setFill()
        board.fill()
        NSColor(calibratedWhite: 0.55, alpha: 1).setStroke()
        board.lineWidth = size * 0.012
        board.stroke()
        // 板上的夹子
        let clipRect = NSRect(x: cbX + cbW * 0.28,
                              y: cbY + cbH - size * 0.11,
                              width: cbW * 0.44,
                              height: size * 0.18)
        let clip = NSBezierPath(roundedRect: clipRect,
                                xRadius: size * 0.025, yRadius: size * 0.025)
        NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.95, alpha: 1).setFill()
        clip.fill()
        NSColor(calibratedWhite: 0.3, alpha: 1).setStroke()
        clip.lineWidth = size * 0.008
        clip.stroke()
        // 夹子内侧条
        let clipInner = NSRect(x: cbX + cbW * 0.34,
                               y: cbY + cbH - size * 0.02,
                               width: cbW * 0.32,
                               height: size * 0.03)
        NSColor(calibratedWhite: 0.25, alpha: 1).setFill()
        NSBezierPath(roundedRect: clipInner, xRadius: size * 0.012, yRadius: size * 0.012).fill()

        // 便签纸上的三行文字
        let lineStartX = cbX + cbW * 0.14
        let lineEndX   = cbX + cbW * 0.86
        let topY = cbY + cbH * 0.70
        for i in 0..<3 {
            let y = topY - CGFloat(i) * cbH * 0.16
            let w = cbW * (i == 2 ? 0.55 : (i == 1 ? 0.75 : 0.68))
            let line = NSBezierPath()
            line.move(to: NSPoint(x: lineStartX, y: y))
            line.line(to: NSPoint(x: min(lineEndX, lineStartX + w), y: y))
            line.lineWidth = size * 0.016
            line.lineCapStyle = .round
            NSColor(calibratedWhite: 0.35, alpha: 0.9).setStroke()
            line.stroke()
        }

        // 复制勾号 ✓（右下角徽章）
        let badgeSize = size * 0.22
        let bx = rect.maxX - size * 0.11 - badgeSize
        let by = rect.minY + size * 0.11
        let badgeRect = NSRect(x: bx, y: by, width: badgeSize, height: badgeSize)
        let badge = NSBezierPath(ovalIn: badgeRect)
        NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.35, alpha: 1).setFill()
        badge.fill()
        NSColor.white.withAlphaComponent(0.95).setStroke()
        // 勾号
        let check = NSBezierPath()
        check.move(to: NSPoint(x: bx + badgeSize * 0.28, y: by + badgeSize * 0.52))
        check.line(to: NSPoint(x: bx + badgeSize * 0.46, y: by + badgeSize * 0.72))
        check.line(to: NSPoint(x: bx + badgeSize * 0.75, y: by + badgeSize * 0.32))
        check.lineWidth = badgeSize * 0.10
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        NSColor.white.setStroke()
        check.stroke()
    }

    // MARK: - MenuBar Icon (状态栏图标)

    /// 菜单栏状态栏图标（18px 模板图：便签纸轮廓 + 复制符号）。
    static func makeStatusBarImage(length: CGFloat = 18) -> NSImage {
        let img = NSImage(size: NSSize(width: length, height: length))
        img.isTemplate = true
        img.lockFocus()
        let rect = CGRect(x: 1, y: 1, width: length - 2, height: length - 2)
        // 便签纸外框
        let r = length * 0.12
        let paper = NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r)
        paper.lineWidth = 1.2
        NSColor.black.setStroke()
        paper.stroke()
        // 右上折角
        let foldL = length * 0.28
        let fold = NSBezierPath()
        fold.move(to: NSPoint(x: rect.maxX - foldL, y: rect.maxY))
        fold.line(to: NSPoint(x: rect.maxX, y: rect.maxY - foldL))
        fold.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        fold.close()
        NSColor.black.setFill()
        fold.fill()
        // 复制符号（两个重叠矩形）
        let sw = length * 0.36
        let sh = length * 0.36
        let sx = rect.minX + length * 0.20
        let sy = rect.minY + length * 0.18
        let front = NSBezierPath(roundedRect: NSRect(x: sx, y: sy, width: sw, height: sh),
                                 xRadius: length * 0.06, yRadius: length * 0.06)
        front.lineWidth = 1.1
        NSColor.black.setStroke()
        front.stroke()
        let back = NSBezierPath(roundedRect: NSRect(x: sx + length * 0.14,
                                                     y: sy + length * 0.14,
                                                     width: sw, height: sh),
                                xRadius: length * 0.06, yRadius: length * 0.06)
        back.lineWidth = 1.1
        NSColor.black.setStroke()
        back.stroke()
        img.unlockFocus()
        return img
    }
}
