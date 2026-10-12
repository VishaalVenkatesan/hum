import Foundation
import Observation

@MainActor
@Observable
final class SleepTimer {
    private(set) var endDate: Date?

    @ObservationIgnored private var task: Task<Void, Never>?

    static let presets = [15, 30, 45, 60, 90]
    private static let fadeDuration: TimeInterval = 30

    var isActive: Bool { endDate != nil }

    func start(minutes: Int, store: SpeakerStore) {
        cancel()
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
        endDate = end
        task = Task { [weak self] in
            let wait = max(end.timeIntervalSinceNow - Self.fadeDuration, 0)
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            await store.fadeOutAndPause(over: min(Self.fadeDuration, end.timeIntervalSinceNow))
            guard !Task.isCancelled else { return }
            self?.endDate = nil
            self?.task = nil
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        endDate = nil
    }
}
