import SwiftUI

struct RoomPickerMenu: View {
    @Environment(SpeakerStore.self) private var store
    let group: SonosGroup

    var body: some View {
        Menu {
            Section("Control") {
                ForEach(store.groups) { candidate in
                    Button {
                        store.selectedGroupID = candidate.id
                    } label: {
                        if candidate.id == group.id {
                            Label(candidate.name, systemImage: "checkmark")
                        } else {
                            Text(candidate.name)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: group.members.count > 1 ? "hifispeaker.2.fill" : "hifispeaker.fill")
                Text(group.name)
                if store.groups.count > 1 {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .opacity(0.7)
                }
            }
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.white.opacity(0.14), in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(store.groups.count < 2)
    }
}

struct MoveMusicMenu: View {
    @Environment(SpeakerStore.self) private var store
    let group: SonosGroup

    private var targets: [SonosGroup] { store.groups.filter { $0.id != group.id } }

    var body: some View {
        Menu {
            Section("Move music to") {
                ForEach(targets) { target in
                    Button(target.name) {
                        Task { await store.moveMusic(from: group, to: target) }
                    }
                }
            }
            Section("Play here too") {
                ForEach(targets) { target in
                    Button(target.name) {
                        for member in target.members {
                            store.join(member, to: group)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "hifispeaker.arrow.forward")
                .opacity(targets.isEmpty ? 0.25 : 0.6)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(targets.isEmpty)
        .help(targets.isEmpty ? "Add another speaker to move music around" : "Move or share this music")
    }
}
