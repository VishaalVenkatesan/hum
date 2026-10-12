import SwiftUI

struct MenuContentView: View {
    @Environment(SpeakerStore.self) private var store
    @State private var page = Page.main

    private enum Page {
        case main
        case sound
    }

    var body: some View {
        ZStack {
            switch page {
            case .main:
                MainPage(onOpenSound: { page = .sound })
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .sound:
                SoundSettingsView(onBack: { page = .main })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: 340)
        .animation(.spring(duration: 0.35, bounce: 0.1), value: page)
    }
}

private struct MainPage: View {
    @Environment(SpeakerStore.self) private var store
    let onOpenSound: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let group = store.heroGroup {
                ScrollView {
                    VStack(spacing: 16) {
                        HeroPlayerView(group: group)
                            .id(group.id)
                            .transition(.opacity)
                        RoomsSection()
                    }
                    .padding(12)
                    .animation(.spring(duration: 0.4), value: group.id)
                }
                .scrollIndicators(.never)
                .frame(maxHeight: 620)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                EmptyStateView()
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity)
            }

            Divider()

            BottomBar(onOpenSound: onOpenSound)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
    }
}

private struct EmptyStateView: View {
    @Environment(SpeakerStore.self) private var store

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "hifispeaker.2")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, isActive: store.isDiscovering)
            Text(store.isDiscovering ? "Listening for speakers…" : store.errorMessage ?? "Listening for speakers…")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !store.isDiscovering {
                Button("Try Again") { Task { await store.rediscover() } }
                    .controlSize(.small)
            }
        }
    }
}

private struct BottomBar: View {
    @Environment(SpeakerStore.self) private var store
    let onOpenSound: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            SleepTimerMenu()
            Button(action: onOpenSound) {
                Image(systemName: "slider.vertical.3")
            }
            .buttonStyle(PressableStyle())
            .disabled(store.allMembers.isEmpty)
            .help("Bass, treble and loudness")
            Spacer()
            if store.isDiscovering {
                ProgressView()
                    .controlSize(.mini)
            }
            Button {
                Task { await store.rediscover() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(PressableStyle())
            .help("Search for speakers again")
            SettingsMenu()
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
    }
}
