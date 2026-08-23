import AppKit
import CoreGraphics

let pidStr = ProcessInfo.processInfo.environment["CN_PID"] ?? "0"
let pid = Int32(pidStr) ?? 0
let opts: CGWindowListOption = [.optionOnScreenOnly, .optionIncludingWindow]
guard let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
    print("no window info"); exit(1)
}
var found = 0
for w in info {
    if let owner = w[kCGWindowOwnerPID as String] as? Int32, owner == pid {
        found += 1
        let name = w[kCGWindowName as String] as? String ?? "(none)"
        let layer = w[kCGWindowLayer as String] as? Int ?? 0
        let alpha = w[kCGWindowAlpha as String] as? Double ?? 1.0
        let bounds = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
        print("WINDOW layer=\(layer) alpha=\(alpha) name=\(name) bounds=\(bounds)")
    }
}
print("total windows for pid \(pid): \(found)")
