import SwiftUI

struct SleepTimerMenu: View {
    @Environment(SpeakerStore.self) private var store
    @Environment(SleepTimer.self) private var sleepTimer

    private var endDate: Date? { sleepTimer.endDate ?? store.speakerSleepTimerEnd }

    var body: some View {
        Menu {
            Section("Fade out and stop in") {
                ForEach(SleepTimer.presets, id: \.self) { minutes in
                    Button("\(minutes) minutes") { sleepTimer.start(minutes: minutes, store: store) }
                }
            }
            if endDate != nil {
                Divider()
                Button("Cancel Sleep Timer") {
                    sleepTimer.cancel(store: store)
                    store.cancelSpeakerSleepTimers()
                }
            }
            Divider()
            Text("Runs on the speaker, so it works even if your Mac sleeps")
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
        if let endDate {
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
