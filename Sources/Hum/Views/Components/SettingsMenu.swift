import ServiceManagement
import SwiftUI

struct SettingsMenu: View {
    @Environment(AppController.self) private var app
    @AppStorage(Preferences.showTrackInMenuBar) private var showTrack = true
    @AppStorage(Preferences.hotKeysEnabled) private var hotKeysEnabled = true
    @AppStorage(Preferences.mediaKeysEnabled) private var mediaKeysEnabled = true
    @AppStorage(Preferences.callBehavior) private var callBehavior = CallBehavior.lower
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Menu {
            Toggle("Show Song in Menu Bar", isOn: $showTrack)
            Toggle("Media Keys & Control Center", isOn: $mediaKeysEnabled)
            Picker("When I'm on a Call", selection: $callBehavior) {
                ForEach(CallBehavior.allCases) { behavior in
                    Text(behavior.title).tag(behavior)
                }
            }
            Toggle("Open at Login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
            Divider()
            Toggle("Keyboard Shortcuts", isOn: $hotKeysEnabled)
            if hotKeysEnabled {
                Section("Shortcuts") {
                    ForEach(app.hotKeys, id: \.label) { hotKey in
                        Text("\(HotKey.modifierSymbols)\(Self.symbol(for: hotKey.keyCode))   \(hotKey.label)")
                    }
                }
            }
            Divider()
            Button("Quit Hum") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "gearshape")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func setLaunchAtLogin(_ value: Bool) {
        do {
            if value {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSSound.beep()
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private static func symbol(for keyCode: Int) -> String {
        switch keyCode {
        case 126: "↑"
        case 125: "↓"
        case 124: "→"
        case 123: "←"
        case 49: "Space"
        case 46: "M"
        default: "?"
        }
    }
}
