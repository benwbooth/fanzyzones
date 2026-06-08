import AppKit
import Carbon.HIToolbox

/// Registers global keyboard shortcuts via Carbon's hot-key API (the reliable way to
/// get *consumed* system-wide shortcuts). Defaults:
///   ⌃⌥← / ⌃⌥→  — move the focused window to the previous / next zone
///   ⌃⌥1 … ⌃⌥9  — move the focused window to that zone number
@MainActor
final class HotkeyManager {
    enum Action: Equatable {
        case zone(Int)     // zero-based zone index
        case next
        case prev
    }

    private let onAction: (Action) -> Void
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var actionsById: [UInt32: Action] = [:]
    private var handler: EventHandlerRef?
    private var nextId: UInt32 = 1
    private var installed = false

    /// 'FZKY' as an OSType signature for our hot keys.
    private let signature: OSType = 0x465A4B59

    init(onAction: @escaping (Action) -> Void) {
        self.onAction = onAction
    }

    func register() {
        guard !installed else { return }
        installed = true
        installHandler()

        let mods = UInt32(controlKey | optionKey)
        add(keyCode: UInt32(kVK_RightArrow), modifiers: mods, action: .next)
        add(keyCode: UInt32(kVK_LeftArrow), modifiers: mods, action: .prev)

        let digitKeys: [Int] = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
                                kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        for (index, key) in digitKeys.enumerated() {
            add(keyCode: UInt32(key), modifiers: mods, action: .zone(index))
        }
    }

    func unregister() {
        for ref in hotKeyRefs { if let ref { UnregisterEventHotKey(ref) } }
        hotKeyRefs.removeAll()
        actionsById.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
        installed = false
        nextId = 1
    }

    // MARK: - Private

    private func add(keyCode: UInt32, modifiers: UInt32, action: Action) {
        let id = nextId
        nextId += 1
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRefs.append(ref)
            actionsById[id] = action
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userInfo in
            guard let event, let userInfo else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            MainActor.assumeIsolated { manager.dispatch(id: hkID.id) }
            return noErr
        }, 1, &eventType, userInfo, &handler)
    }

    private func dispatch(id: UInt32) {
        if let action = actionsById[id] { onAction(action) }
    }
}
