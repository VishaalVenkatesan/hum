import SwiftUI

struct RoomsSection: View {
    @Environment(SpeakerStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rooms")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                GroupingMenu()
            }
            .padding(.horizontal, 4)

            if store.allMembers.count > 1 {
                PillSlider(
                    title: "All Rooms",
                    level: store.averageVolume,
                    muted: store.isMuted(store.allMembers),
                    onChange: { store.setVolume($0, across: store.allMembers) },
                    onToggleMute: { store.setMuted(!store.isMuted(store.allMembers), members: store.allMembers) }
                )
            }

            ForEach(store.groups) { group in
                RoomRow(group: group)
            }
        }
    }
}

private struct RoomRow: View {
    @Environment(SpeakerStore.self) private var store
    let group: SonosGroup
    @State private var expanded = false

    private var isGrouped: Bool { group.members.count > 1 }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                PillSlider(
                    title: group.name,
                    level: store.groupVolume(group),
                    muted: store.isMuted(group.members),
                    onChange: { level in
                        if isGrouped {
                            store.setVolume(level, across: group.members)
                        } else {
                            store.setVolume(level, for: group.coordinator)
                        }
                    },
                    onToggleMute: { store.setMuted(!store.isMuted(group.members), members: group.members) }
                )
                .overlay(alignment: .topTrailing) {
                    if store.isPlaying(group) {
                        Circle()
                            .fill(.green)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                            .offset(x: 1, y: -1)
                            .transition(.scale)
                    }
                }

                if isGrouped {
                    Button {
                        expanded.toggle()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .frame(width: 22, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .foregroundStyle(.secondary)
                }
            }

            if isGrouped && expanded {
                ForEach(group.members) { member in
                    PillSlider(
                        title: member.name,
                        level: store.volumes[member.id]?.level ?? 0,
                        muted: store.volumes[member.id]?.muted ?? false,
                        height: 26,
                        onChange: { store.setVolume($0, for: member) },
                        onToggleMute: { store.toggleMute(member) }
                    )
                    .padding(.leading, 14)
                    .padding(.trailing, 28)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: expanded)
        .animation(.spring(duration: 0.3), value: store.isPlaying(group))
    }
}

private struct GroupingMenu: View {
    @Environment(SpeakerStore.self) private var store

    var body: some View {
        Menu {
            Button("Group All Rooms") { Task { await store.groupAll() } }
                .disabled(!store.canGroupAll)
            Button("Ungroup All Rooms") { Task { await store.ungroupAll() } }
                .disabled(!store.hasGroupedRooms)
            if store.allMembers.count > 1 {
                Divider()
                ForEach(store.allMembers) { member in
                    MemberGroupingMenu(member: member)
                }
            }
        } label: {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Group rooms")
    }
}

private struct MemberGroupingMenu: View {
    @Environment(SpeakerStore.self) private var store
    let member: SonosMember

    private var currentGroup: SonosGroup? { store.groups.first { $0.members.contains(member) } }

    var body: some View {
        Menu(member.name) {
            ForEach(store.groups.filter { $0.id != currentGroup?.id }) { target in
                Button("Join \(target.name)") { store.join(member, to: target) }
            }
            if (currentGroup?.members.count ?? 0) > 1 {
                Divider()
                Button("Leave \(currentGroup?.name ?? "Group")") { store.ungroup(member) }
            }
        }
    }
}
