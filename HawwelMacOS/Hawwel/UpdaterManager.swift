import SwiftUI
import Combine
import Sparkle

/// غلاف حوالين Sparkle: التحقق من التحديثات وتنزيلها من GitHub Releases.
final class UpdaterManager: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    @Published var canCheckForUpdates = false
    @Published var automaticallyChecks = true

    private var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        AppMode.prepareForUpdateUI()
        controller.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ on: Bool) {
        controller.updater.automaticallyChecksForUpdates = on
        automaticallyChecks = on
    }

    // MARK: - SPUStandardUserDriverDelegate
    // التطبيق شغّال في المنيو بار (من غير Dock)، فلازم نطلّع نافذة التحديث قدّام بنفسنا.

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
                                                             andInImmediateFocus immediateFocus: Bool) -> Bool {
        true
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                   forUpdate update: SUAppcastItem,
                                                   state: SPUUserUpdateState) {
        if handleShowingUpdate { AppMode.prepareForUpdateUI() }
    }
}
