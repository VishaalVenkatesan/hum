import SwiftUI

struct SoundSettingsView: View {
    @Environment(SpeakerStore.self) private var store
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Sound")
                            .font(.headline)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.allMembers) { member in
                        SpeakerSoundCard(member: member)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.never)
        }
    }
}

private struct SpeakerSoundCard: View {
    @Environment(SpeakerStore.self) private var store
    let member: SonosMember

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(member.name)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if store.sound[member.id] != nil && store.sound[member.id] != .flat {
                    Button("Reset") { store.resetSound(for: member) }
                        .buttonStyle(.borderless)
                        .font(.system(size: 11))
                        .transition(.opacity)
                }
            }

            if let settings = store.sound[member.id] {
                EQRow(title: "Bass", value: settings.bass) { store.setBass($0, for: member) }
                EQRow(title: "Treble", value: settings.treble) { store.setTreble($0, for: member) }
                Toggle(isOn: Binding(get: { settings.loudness }, set: { store.setLoudness($0, for: member) })) {
                    Text("Loudness")
                        .font(.system(size: 12))
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: store.sound[member.id])
        .task { await store.loadSound(for: member) }
    }
}

private struct EQRow: View {
    let title: String
    let value: Int
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12))
                .frame(width: 48, alignment: .leading)
            CenteredBar(value: value, range: 10, onChange: onChange)
            Text(value > 0 ? "+\(value)" : "\(value)")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
        }
    }
}

private struct CenteredBar: View {
    let value: Int
    let range: Int
    let onChange: (Int) -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let mid = width / 2
            let offset = CGFloat(value) / CGFloat(range) * mid
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: abs(offset))
                    .offset(x: offset >= 0 ? mid : mid + offset)
                Rectangle()
                    .fill(Color.primary.opacity(0.35))
                    .frame(width: 1.5, height: 12)
                    .offset(x: mid - 0.75)
            }
            .frame(height: 6)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { drag in
                    let ratio = (drag.location.x - mid) / mid
                    let next = Int((ratio * CGFloat(range)).rounded())
                    let clamped = min(max(next, -range), range)
                    if clamped != value { onChange(clamped) }
                }
            )
            .animation(.easeOut(duration: 0.1), value: value)
        }
        .frame(height: 18)
    }
}
