import AppKit

enum AppMode {
    /// بيتعبّى من MyApp علشان نقدر نفتح النافذة من أي مكان
    static var openMain: (() -> Void)?
    static var launchHandled = false

    static var menuBarEnabled: Bool {
        UserDefaults.standard.object(forKey: "showMenuBar") as? Bool ?? true
    }

    static func showDock() {
        NSApp.setActivationPolicy(.regular)

        // ننتظر لحظة علشان ماك يخلّص تحويل الوضع، وبعدين نجيب النافذة قدّام
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    static func hideDock() {
        if menuBarEnabled { NSApp.setActivationPolicy(.accessory) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.automaticTerminationSupportEnabled = false
        // نبدأ مخفي من الـ Dock لو المنيو بار شغّال
        AppMode.hideDock()

        // لما آخر نافذة تتقفل: نخفي الـ Dock تاني
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { note in
            guard let closing = note.object as? NSWindow else { return }
            DispatchQueue.main.async {
                let othersOpen = NSApp.windows.contains {
                    $0 !== closing && $0.isVisible && $0.canBecomeMain
                }
                if !othersOpen { AppMode.hideDock() }
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
    
    /// لما تفتح التطبيق من Spotlight أو Finder وهو شغال في الخلفية
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, let open = AppMode.openMain {
            open()
            return false
        }
        return true
    }
}
