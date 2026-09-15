import Testing
@testable import MoePeek

@Suite @MainActor struct UpdaterControllerTests {
    @Test func personalBuildNeverStartsSparkle() {
        let updater = UpdaterController(updatesDisabled: true)
        #expect(!updater.isUpdateServiceEnabled)
        #expect(!updater.canCheckForUpdates)
        #expect(!updater.automaticallyChecksForUpdates)
        updater.checkForUpdates()
        #expect(!updater.canCheckForUpdates)
    }
}
