import Combine
import Foundation
import Sparkle

@MainActor
@Observable
final class UpdaterController {
    private let sparkleController: SPUStandardUpdaterController?
    private var cancellable: AnyCancellable?

    private(set) var canCheckForUpdates = false

    var isUpdateServiceEnabled: Bool { sparkleController != nil }

    var automaticallyChecksForUpdates: Bool = false {
        didSet {
            sparkleController?.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    init(updatesDisabled: Bool = Bundle.main.object(forInfoDictionaryKey: "MoePeekDisableUpdates") as? Bool == true) {
        guard !updatesDisabled else {
            sparkleController = nil
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        sparkleController = controller
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        canCheckForUpdates = controller.updater.canCheckForUpdates

        cancellable = controller.updater
            .publisher(for: \.canCheckForUpdates)
            .sink { [weak self] value in
                Task { @MainActor in
                    self?.canCheckForUpdates = value
                }
            }
    }

    func checkForUpdates() {
        sparkleController?.checkForUpdates(nil)
    }
}
