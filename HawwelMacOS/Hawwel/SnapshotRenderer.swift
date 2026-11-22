import SwiftUI
import AppKit

/// أداة للمطوّر: بترسم كل التابات (عربي/إنجليزي، فاتح/داكن) في صور PNG وتقفل.
/// التشغيل: Hawwel -HawwelSnapshot /path/to/folder   (في نسخة Debug بس)
enum SnapshotRenderer {
    static var active = false

    #if DEBUG
    static func scheduleIfRequested(engine: Engine) {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-HawwelSnapshot"), i + 1 < args.count else { return }
        active = true
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            render(to: dir, engine: engine)
            NSApp.terminate(nil)
        }
    }

    private static func demoStats() -> Stats {
        var d = Stats.Data()
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        for (back, n) in [6: 8, 5: 14, 4: 6, 3: 21, 2: 17, 1: 11, 0: 12] {
            let day = f.string(from: cal.date(byAdding: .day, value: -back, to: Date())!)
            d.days[day] = n
            d.dayChars[day] = n * 40
        }
        d.total = 1284; d.chars = 52_000; d.toArabic = 873; d.toEnglish = 411
        d.apps = ["Slack": 46, "WhatsApp": 31, "Chrome": 23]
        return Stats(preview: d)
    }

    private static func render(to dir: URL, engine: Engine) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let updater = UpdaterManager()
        let recorder = ShortcutRecorder()
        let stats = demoStats()
        let suite = UserDefaults(suiteName: "hawwel.snapshot")!

        let normal = NSSize(width: HW.panelWidth, height: HW.panelHeight)
        var jobs: [(AppLanguage, String, Tab, Bool, NSSize, String)] = []
        for lang in AppLanguage.allCases {
            for theme in ["light", "dark"] {
                for tab in Tab.allCases { jobs.append((lang, theme, tab, false, normal, "")) }
                jobs.append((lang, theme, .home, true, normal, ""))
            }
            // أصغر حجم وحجم كبير
            for tab in [Tab.home, .activity] {
                jobs.append((lang, "light", tab, false, NSSize(width: HW.minWidth, height: HW.minHeight), "-min"))
                jobs.append((lang, "light", tab, false, NSSize(width: 1100, height: 720), "-large"))
            }
        }

        for (lang, theme, tab, collapsed, size, suffix) in jobs {
            AppLanguage.override = lang
            suite.set(lang.rawValue, forKey: Prefs.language)
            suite.set(theme, forKey: Prefs.appearance)
            suite.set(collapsed, forKey: Prefs.sidebarCollapsed)
            let appearance = NSAppearance(named: theme == "dark" ? .darkAqua : .aqua)
            NSApp.appearance = appearance

            let root = ContentView(initialTab: tab)
                .environmentObject(engine)
                .environmentObject(updater)
                .environmentObject(stats)
                .environmentObject(recorder)
                .defaultAppStorage(suite)
            let host = NSHostingView(rootView: root)
            let rect = NSRect(origin: .zero, size: size)
            host.frame = rect
            let window = NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = appearance
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.35))

            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: rep)
            let name = "\(lang.rawValue)-\(theme)-\(tab.rawValue)\(collapsed ? "-collapsed" : "")\(suffix).png"
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent(name))
            window.contentView = nil
        }
        suite.removePersistentDomain(forName: "hawwel.snapshot")
    }
    #endif
}
