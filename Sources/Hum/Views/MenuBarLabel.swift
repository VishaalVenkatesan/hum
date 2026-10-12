import SwiftUI

struct MenuBarLabel: View {
    @Environment(AppController.self) private var app
    @Environment(SpeakerStore.self) private var store
    @AppStorage(Preferences.showTrackInMenuBar) private var showTrack = true
    @AppStorage(Preferences.hotKeysEnabled) private var hotKeysEnabled = true
    @AppStorage(Preferences.mediaKeysEnabled) private var mediaKeysEnabled = true
    @AppStorage(Preferences.callBehavior) private var callBehavior = CallBehavior.lower

    private static let maxLength = 28

    private var heroNowPlaying: NowPlaying? {
        store.heroGroup.flatMap { store.nowPlaying[$0.id] }
    }

    private var trackText: String? {
        guard showTrack, let nowPlaying = heroNowPlaying, nowPlaying.state.isPlaying, let headline = nowPlaying.headline else { return nil }
        return headline.count > Self.maxLength ? String(headline.prefix(Self.maxLength - 1)) + "…" : headline
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: store.anyPlaying ? "hifispeaker.2.fill" : "hifispeaker.2")
            if let trackText {
                Text(trackText)
            }
        }
        .task { app.start() }
        .onChange(of: hotKeysEnabled, initial: true) { _, enabled in
            app.setHotKeys(enabled: enabled)
        }
        .onChange(of: mediaKeysEnabled, initial: true) { _, enabled in
            app.setMediaKeys(enabled: enabled)
        }
        .onChange(of: heroNowPlaying) {
            Task { await app.syncNowPlaying() }
        }
        .onChange(of: app.callMonitor.isMicInUse) { _, active in
            app.handleCall(active: active, behavior: callBehavior)
        }
    }
}
