import AppKit
import Carbon.HIToolbox

/// 全局快捷键管理器：注册并处理系统级热键（不依赖应用激活状态）。
/// 支持自定义快捷键绑定：通过 `HotkeyConfigStore` 读取 `.toggleWindow` 绑定。
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onTrigger: (() -> Void)?

    private var hotKeyID = EventHotKeyID(signature: OSType(0x434E3031), id: 1) // "CN01"

    private init() {}

    deinit { unregister() }

    /// 注册全局热键：从 HotkeyConfigStore 读取 `.toggleWindow` 绑定。
    /// 重复注册会先注销旧的。
    @discardableResult
    func registerToggleKey(handler: @escaping () -> Void) -> Bool {
        unregister()
        self.onTrigger = handler

        // 从配置读取绑定
        let binding = MainActor.assumeIsolated {
            HotkeyConfigStore.shared.binding(for: .toggleWindow)
        }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var handlerRef: EventHandlerRef?
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), {
            (_, eventRef, userData) -> OSStatus in
            guard let eventRef, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(eventRef,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hotKeyID)
            if status == noErr {
                let mgr = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                if hotKeyID.id == mgr.hotKeyID.id {
                    DispatchQueue.main.async { mgr.onTrigger?() }
                }
            }
            return noErr
        }, 1, &spec, selfPtr, &handlerRef)

        guard installStatus == noErr, let handlerRef else { return false }
        self.eventHandler = handlerRef

        let modifiers = binding.carbonModifiers
        let keyCode = binding.keyCode
        var ref: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                            GetApplicationEventTarget(), 0, &ref)
        if regStatus == noErr, let ref {
            self.hotKeyRef = ref
            return true
        } else {
            RemoveEventHandler(handlerRef)
            self.eventHandler = nil
            return false
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandler {
            RemoveEventHandler(ref)
            eventHandler = nil
        }
        onTrigger = nil
    }
}
