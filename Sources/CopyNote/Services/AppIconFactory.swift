import AppKit
import SwiftUI

/// 统一加载 CopyNote 图标资源：
/// - 首选：从 CopyNote.app/Contents/Resources 读取真实 PNG / ICNS 文件
/// - 兜底：使用代码绘制旧版本图标（保证开发环境无 .app 时仍能显示）
enum AppIconFactory {

    // MARK: - Resource Helpers

    /// 显式查找 Resources 目录：
    /// - 优先：CopyNote.app/Contents/Resources（由 build_and_run.sh 拷贝）
    /// - 其次：源码项目 Resources/（SwiftPM 直接 swift run 时）
    private static var resourcesURL: URL? {
        let fm = FileManager.default
        // 1) .app 场景：Bundle.main.executableURL = .../CopyNote.app/Contents/MacOS/CopyNote
        //    往上两级 -> Contents -> Resources
        if let exe = Bundle.main.executableURL {
            var u = exe.deletingLastPathComponent() // MacOS
            u = u.deletingLastPathComponent()       // Contents
            let r = u.appendingPathComponent("Resources", isDirectory: true)
            if fm.fileExists(atPath: r.path) { return r }
        }
        // 2) Bundle.main.resourceURL 可能已经是 .app/Contents/Resources 的情况
        if let r = Bundle.main.resourceURL, fm.fileExists(atPath: r.path) {
            // 检查是否有我们的资源
            let probe = r.appendingPathComponent("app-64.png")
            if fm.fileExists(atPath: probe.path) { return r }
        }
        // 3) 源码目录 fallback：从可执行文件找项目根（典型 SwiftPM .build 子目录）
        if let exe = Bundle.main.executableURL {
            var u = exe
            // 最多向上爬 6 层找 Resources/
            for _ in 0..<6 {
                let r = u.appendingPathComponent("Resources", isDirectory: true)
                let probe = r.appendingPathComponent("app-64.png")
                if fm.fileExists(atPath: probe.path) { return r }
                u = u.deletingLastPathComponent()
            }
        }
        return nil
    }

    private final class BundleAnchor: NSObject {}

    private static func loadPNG(_ name: String, extension ext: String = "png") -> NSImage? {
        guard let base = resourcesURL else { return nil }
        let url = base.appendingPathComponent("\(name).\(ext)")
        return NSImage(contentsOf: url)
    }

    private static func loadICNS(_ name: String) -> NSImage? {
        guard let base = resourcesURL else { return nil }
        let url = base.appendingPathComponent("\(name).icns")
        return NSImage(contentsOf: url)
    }

    // MARK: - AppIcon (Dock / Finder / 关于页)

    /// 生成 CopyNote App 图标。优先读 bundle 的 AppIcon.icns / app-512.png；失败则代码绘制
    static func makeAppIcon(size: CGFloat = 512) -> NSImage {
        // 尝试 icns
        if let icns = loadICNS("AppIcon") {
            if size == 512 { return icns }
            let resized = NSImage(size: NSSize(width: size, height: size))
            resized.lockFocus()
            icns.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                      from: NSRect.zero,
                      operation: .sourceOver,
                      fraction: 1)
            resized.unlockFocus()
            return resized
        }
        // 尝试高分辨率 PNG
        if let hi = loadPNG("app-512") ?? loadPNG("app-128") ?? loadPNG("app-64") {
            if size == 512 { return hi }
            let resized = NSImage(size: NSSize(width: size, height: size))
            resized.lockFocus()
            hi.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
            resized.unlockFocus()
            return resized
        }
        // 兜底：代码绘制（旧版本）
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let ctx = NSGraphicsContext.current?.cgContext
        drawAppIconFallback(in: CGRect(x: 0, y: 0, width: size, height: size), ctx: ctx)
        image.unlockFocus()
        return image
    }

    // MARK: - MenuBar Status Icon (模板图)

    /// 状态栏图标：优先加载 Resources 中与 AppIcon 同款的新版单色模板 PNG；
    /// 失败则使用代码绘制的单色轮廓符号兜底。均为模板图，跟随系统菜单色。
    /// （模板化只认 alpha 通道：新版 PNG 为「黑色实心 + 透明挖洞」，不会变实心方块）
    static func makeStatusBarImage(length: CGFloat = 18) -> NSImage {
        let base = length <= 16 ? "statusbar-16" : "statusbar-18"
        // 优先 @2x（retina 下更清晰），其次 1x
        if let img = loadStatusBarPNG("\(base)@2x") ?? loadStatusBarPNG(base) {
            img.isTemplate = true
            guard abs(img.size.width - length) > 0.5 else { return img }
            let resized = NSImage(size: NSSize(width: length, height: length))
            resized.lockFocus()
            img.draw(in: NSRect(x: 0, y: 0, width: length, height: length))
            resized.unlockFocus()
            resized.isTemplate = true
            return resized
        }
        return drawStatusBarFallback(length: length)
    }

    /// 加载 statusbar PNG 并正确处理 @2x 缩放（像素 2x → point 尺寸减半）
    private static func loadStatusBarPNG(_ name: String) -> NSImage? {
        guard let base = resourcesURL else { return nil }
        let url = base.appendingPathComponent("\(name).png")
        guard let data = try? Data(contentsOf: url),
              let rep = NSBitmapImageRep(data: data) else { return nil }
        if name.hasSuffix("@2x") {
            // 2x 文件：像素宽度是 point 尺寸的 2 倍，设置 rep.size 使 NSImage 按 point 渲染
            rep.size = NSSize(width: rep.pixelsWide / 2, height: rep.pixelsHigh / 2)
        }
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }

    // MARK: - Fallback (legacy code-drawing)

    private static func drawAppIconFallback(in rect: CGRect, ctx: CGContext?) {
        let size = rect.width
        let corner = size * 0.185
        let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04),
                                   xRadius: corner, yRadius: corner)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 1.00, green: 0.93, blue: 0.58, alpha: 1),
            NSColor(calibratedRed: 0.98, green: 0.79, blue: 0.32, alpha: 1)
        ])
        gradient?.draw(in: bgPath, angle: -45)
        NSColor.black.withAlphaComponent(0.08).setFill()
        let shadow = NSBezierPath(roundedRect: NSRect(
            x: rect.minX + size * 0.04,
            y: rect.minY + rect.height - size * 0.18,
            width: size * 0.92,
            height: size * 0.14
        ), xRadius: corner * 0.8, yRadius: corner * 0.8)
        shadow.fill()

        let foldSize = size * 0.18
        let fold = NSBezierPath()
        fold.move(to: NSPoint(x: rect.maxX - size * 0.04, y: rect.maxY - size * 0.04 - foldSize))
        fold.line(to: NSPoint(x: rect.maxX - size * 0.04 - foldSize, y: rect.maxY - size * 0.04))
        fold.line(to: NSPoint(x: rect.maxX - size * 0.04, y: rect.maxY - size * 0.04))
        fold.close()
        NSColor(calibratedRed: 0.90, green: 0.68, blue: 0.22, alpha: 1).setFill()
        fold.fill()

        let cbW = size * 0.42
        let cbH = size * 0.52
        let cbX = rect.midX - cbW / 2
        let cbY = rect.midY - cbH / 2 - size * 0.02
        let boardRect = NSRect(x: cbX, y: cbY, width: cbW, height: cbH)
        let board = NSBezierPath(roundedRect: boardRect,
                                 xRadius: size * 0.04, yRadius: size * 0.04)
        NSColor.white.withAlphaComponent(0.95).setFill()
        board.fill()
        NSColor(calibratedWhite: 0.55, alpha: 1).setStroke()
        board.lineWidth = size * 0.012
        board.stroke()
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
        let clipInner = NSRect(x: cbX + cbW * 0.34,
                               y: cbY + cbH - size * 0.02,
                               width: cbW * 0.32,
                               height: size * 0.03)
        NSColor(calibratedWhite: 0.25, alpha: 1).setFill()
        NSBezierPath(roundedRect: clipInner, xRadius: size * 0.012, yRadius: size * 0.012).fill()

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

        let badgeSize = size * 0.22
        let bx = rect.maxX - size * 0.11 - badgeSize
        let by = rect.minY + size * 0.11
        let badgeRect = NSRect(x: bx, y: by, width: badgeSize, height: badgeSize)
        let badge = NSBezierPath(ovalIn: badgeRect)
        NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.35, alpha: 1).setFill()
        badge.fill()
        NSColor.white.withAlphaComponent(0.95).setStroke()
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

    private static func drawStatusBarFallback(length: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: length, height: length))
        img.isTemplate = true
        img.lockFocus()
        let rect = CGRect(x: 1, y: 1, width: length - 2, height: length - 2)
        let r = length * 0.12
        let paper = NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r)
        paper.lineWidth = 1.2
        NSColor.black.setStroke()
        paper.stroke()
        let foldL = length * 0.28
        let fold = NSBezierPath()
        fold.move(to: NSPoint(x: rect.maxX - foldL, y: rect.maxY))
        fold.line(to: NSPoint(x: rect.maxX, y: rect.maxY - foldL))
        fold.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        fold.close()
        NSColor.black.setFill()
        fold.fill()
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
