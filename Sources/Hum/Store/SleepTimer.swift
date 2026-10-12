import Foundation
import Observation

@MainActor
@Observable
final class SleepTimer {
    private(set) var endDate: Date?

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var timedGroups: [SonosGroup] = []

    static let presets = [15, 30, 45, 60, 90]
    private static let fadeDuration: TimeInterval = 30

    var isActive: Bool { endDate != nil }

    func start(minutes: Int, store: SpeakerStore) {
        cancel(store: store)
        let duration = TimeInterval(minutes * 60)
        let end = Date().addingTimeInterval(duration)
        endDate = end

        let playing = store.groups.filter(store.isPlaying)
        timedGroups = playing.isEmpty ? store.heroGroup.map { [$0] } ?? [] : playing
        store.configureSleepTimer(duration, for: timedGroups)

        task = Task { [weak self] in
            let wait = max(end.timeIntervalSinceNow - Self.fadeDuration, 0)
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            await store.fadeOutAndPause(over: max(min(Self.fadeDuration, end.timeIntervalSinceNow), 0))
            guard !Task.isCancelled else { return }
            self?.endDate = nil
            self?.task = nil
            self?.timedGroups = []
        }
    }

    func cancel(store: SpeakerStore) {
        task?.cancel()
        task = nil
        endDate = nil
        if !timedGroups.isEmpty {
            store.configureSleepTimer(nil, for: timedGroups)
            timedGroups = []
        }
    }
}
