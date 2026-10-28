import Combine
import Foundation

@MainActor
protocol PlaySettingParityAdapting: ObservableObject {
    var skipBackwardSeconds: Int { get set }
    var skipForwardSeconds: Int { get set }
    var longPressSpeedUpEnabled: Bool { get set }
    var longPressPlaybackRate: Float { get set }
    var systemAudioPathEnabled: Bool { get set }

    func bind(sessionStore: PlayerSessionStore)
}

@MainActor
final class PlaySettingParityAdapter: PlaySettingParityAdapting {
    @Published var skipBackwardSeconds: Int = PlayerControlConfig.default.skipBackwardSeconds {
        didSet {
            applyIfNeeded { config in
                config.skipBackwardSeconds = skipBackwardSeconds
            }
        }
    }

    @Published var skipForwardSeconds: Int = PlayerControlConfig.default.skipForwardSeconds {
        didSet {
            applyIfNeeded { config in
                config.skipForwardSeconds = skipForwardSeconds
            }
        }
    }

    @Published var longPressSpeedUpEnabled: Bool = PlayerControlConfig.default.longPressSpeedUpEnabled {
        didSet {
            applyIfNeeded { config in
                config.longPressSpeedUpEnabled = longPressSpeedUpEnabled
            }
        }
    }

    private weak var sessionStore: PlayerSessionStore?
    @Published var longPressPlaybackRate = PlayerControlConfig.default.longPressPlaybackRate {
        didSet { applyIfNeeded { $0.longPressPlaybackRate = longPressPlaybackRate } }
    }
    @Published var systemAudioPathEnabled = PlayerControlConfig.default.systemAudioPathEnabled {
        didSet { applyIfNeeded { $0.systemAudioPathEnabled = systemAudioPathEnabled } }
    }
    private var cancellables = Set<AnyCancellable>()
    private var syncingFromStore = false

    func bind(sessionStore: PlayerSessionStore) {
        if self.sessionStore === sessionStore {
            sync(with: sessionStore.controlConfig)
            return
        }

        self.sessionStore = sessionStore
        sync(with: sessionStore.controlConfig)

        cancellables.removeAll()
        sessionStore.$controlConfig
            .receive(on: DispatchQueue.main)
            .sink { [weak self] config in
                self?.sync(with: config)
            }
            .store(in: &cancellables)
    }

    private func sync(with config: PlayerControlConfig) {
        syncingFromStore = true
        skipBackwardSeconds = config.skipBackwardSeconds
        skipForwardSeconds = config.skipForwardSeconds
        longPressSpeedUpEnabled = config.longPressSpeedUpEnabled
        longPressPlaybackRate = config.longPressPlaybackRate
        systemAudioPathEnabled = config.systemAudioPathEnabled
        syncingFromStore = false
    }

    private func applyIfNeeded(_ update: (inout PlayerControlConfig) -> Void) {
        guard !syncingFromStore, let sessionStore else {
            return
        }
        var config = sessionStore.controlConfig
        update(&config)
        sessionStore.controlConfig = config
    }
}
