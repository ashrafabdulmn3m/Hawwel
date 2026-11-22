import SwiftUI
import Combine
import Sparkle

/// غلاف حوالين Sparkle: التحقق من التحديثات وتنزيلها من GitHub Releases.
final class UpdaterManager: NSObject, ObservableObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    @Published var canCheckForUpdates = false
    @Published var automaticallyChecks = true
    @Published var automaticallyDownloads = false
    /// رقم الإصدار الجديد لو فيه تحديث (بيظهر بانر في الرئيسية)
    @Published private(set) var availableVersion: String?
    @Published private(set) var lastCheck: Date?

    private var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )
        let updater = controller.updater
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        automaticallyChecks = updater.automaticallyChecksForUpdates
        automaticallyDownloads = updater.automaticallyDownloadsUpdates
        lastCheck = updater.lastUpdateCheckDate

        // فحص صامت بعد ما التطبيق يفتح، علشان نعرف نظهر البانر (من غير أي نافذة)
        if automaticallyChecks {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                self?.controller.updater.checkForUpdateInformation()
            }
        }
    }

    func checkForUpdates() {
        AppMode.prepareForUpdateUI()
        controller.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ on: Bool) {
        controller.updater.automaticallyChecksForUpdates = on
        automaticallyChecks = on
    }

    func setAutomaticDownloads(_ on: Bool) {
        controller.updater.automaticallyDownloadsUpdates = on
        automaticallyDownloads = controller.updater.automaticallyDownloadsUpdates
    }

    // MARK: - SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        DispatchQueue.main.async { self.availableVersion = item.displayVersionString }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        DispatchQueue.main.async { self.availableVersion = nil }
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        DispatchQueue.main.async { self.lastCheck = updater.lastUpdateCheckDate ?? Date() }
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
