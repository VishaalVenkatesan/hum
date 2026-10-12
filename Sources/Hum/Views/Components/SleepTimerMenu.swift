import SwiftUI

struct SleepTimerMenu: View {
    @Environment(SpeakerStore.self) private var store
    @Environment(SleepTimer.self) private var sleepTimer

    var body: some View {
        Menu {
            Section("Fade out and pause in") {
                ForEach(SleepTimer.presets, id: \.self) { minutes in
                    Button("\(minutes) minutes") { sleepTimer.start(minutes: minutes, store: store) }
                }
            }
            if sleepTimer.isActive {
                Divider()
                Button("Cancel Sleep Timer") { sleepTimer.cancel() }
            }
        } label: {
            label
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sleep timer")
    }

    @ViewBuilder
    private var label: some View {
        if let endDate = sleepTimer.endDate {
            HStack(spacing: 4) {
                Image(systemName: "moon.zzz.fill")
                Text(timerInterval: Date()...max(endDate, Date()), countsDown: true)
                    .monospacedDigit()
            }
            .foregroundStyle(.indigo)
        } else {
            Image(systemName: "moon.zzz")
        }
    }
}
