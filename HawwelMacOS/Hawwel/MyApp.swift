import SwiftUI

@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var stats: Stats
    @StateObject private var engine: Engine
    @StateObject private var updater = UpdaterManager()
    @StateObject private var recorder = ShortcutRecorder()
    @AppStorage(Prefs.showMenuBar) private var showMenuBar = true
    @AppStorage(Prefs.language) private var language = AppLanguage.ar.rawValue // علشان المنيو يتترجم
    @Environment(\.openWindow) private var openWindow

    init() {
        Prefs.registerDefaults()
        let stats = Stats()
        _stats = StateObject(wrappedValue: stats)
        let engine = Engine(stats: stats)
        _engine = StateObject(wrappedValue: engine)
        #if DEBUG
        SnapshotRenderer.scheduleIfRequested(engine: engine)
        #endif
    }

    var body: some Scene {
        Window("Hawwel", id: "main") {
            ContentView()
                .environmentObject(engine)
                .environmentObject(updater)
                .environmentObject(stats)
                .environmentObject(recorder)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: HW.panelWidth, height: HW.panelHeight)
        .windowResizability(.contentMinSize) // تقدر تكبّرها براحتك، بس مش أصغر من الحد الأدنى

        MenuBarExtra(isInserted: $showMenuBar) {
            Button(L("menu.convert")) { engine.run() }
            Button(L("menu.open")) {
                openWindow(id: "main")
                AppMode.showDock()
            }
            Button(L("menu.update")) { updater.checkForUpdates() }
            Divider()
            Button(L("menu.quit")) { NSApplication.shared.terminate(nil) }
        } label: {
            // لوجو Hawwel المختصر (ح + P) كـ template: الماك بيلوّنه أبيض أو أسود حسب المنيو بار
            Image("MenuBarIcon")
                .onAppear {
                    AppMode.openMain = {
                        openWindow(id: "main")
                        AppMode.showDock()
                    }
                }
        }
    }
}
