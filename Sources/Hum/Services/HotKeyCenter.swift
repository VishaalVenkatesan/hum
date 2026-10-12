import Carbon.HIToolbox

struct HotKey {
    let keyCode: Int
    let label: String
    let action: @MainActor () -> Void

    static let modifiers = UInt32(controlKey | optionKey)
    static let modifierSymbols = "⌃⌥"
}

@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: @MainActor () -> Void] = [:]
    private var handler: EventHandlerRef?
    private static let signature = OSType(0x48554D21)

    func register(_ hotKeys: [HotKey]) {
        unregisterAll()
        installHandlerIfNeeded()
        for (index, hotKey) in hotKeys.enumerated() {
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index + 1))
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(hotKey.keyCode), HotKey.modifiers, id, GetApplicationEventTarget(), 0, &ref)
            guard status == noErr, let ref else { continue }
            refs.append(ref)
            actions[id.id] = hotKey.action
        }
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []
        actions = [:]
    }

    private func fire(_ id: UInt32) {
        actions[id]?()
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &id
            )
            guard status == noErr else { return status }
            let key = id.id
            MainActor.assumeIsolated { HotKeyCenter.shared.fire(key) }
            return noErr
        }, 1, &spec, nil, &handler)
    }
}
