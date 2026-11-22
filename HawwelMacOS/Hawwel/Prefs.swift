import AppKit
import KeyboardShortcuts

/// مفاتيح الإعدادات في UserDefaults وقيمها الافتراضية.
enum Prefs {
    static let appearance = "appearance"          // light | dark | system
    static let language = "uiLanguage"            // ar | en
    static let sidebarCollapsed = "sidebarCollapsed"
    static let showMenuBar = "showMenuBar"
    static let playSound = "playSound"
    static let switchKeyboard = "switchKeyboard"
    static let hasLaunchedBefore = "hasLaunchedBefore"

    /// لازم تتنادى أول حاجة وقت فتح التطبيق
    static func registerDefaults() {
        let d = UserDefaults.standard
        d.register(defaults: [
            appearance: "system",
            sidebarCollapsed: false,
            showMenuBar: true,
            playSound: false,
            switchKeyboard: true,
        ])

        // لغة الواجهة أول مرة: اللي كانوا بيستخدموا Hawwel قبل كده كان عربي،
        // والمستخدم الجديد ياخد لغة الماك (عربي لو الماك عربي، وإلا إنجليزي).
        if d.string(forKey: language) == nil {
            let systemArabic = Locale.preferredLanguages.first?.hasPrefix("ar") == true
            let lang: AppLanguage = d.bool(forKey: hasLaunchedBefore) || systemArabic ? .ar : .en
            d.set(lang.rawValue, forKey: language)
        }

        // 1.3.1 كان فيه نهاري/ليلي بس، وأي قيمة تانية قديمة ("auto") تبقى زي النظام
        if let a = d.string(forKey: appearance), !["light", "dark", "system"].contains(a) {
            d.set("system", forKey: appearance)
        }
    }

    /// بيطبّق المظهر على التطبيق كله (النافذة والمنيو).
    /// بنستخدم NSApp.appearance بدل preferredColorScheme علشان "زي النظام" يرجع صح.
    static func applyAppearance(_ mode: String) {
        switch mode {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":  NSApp.appearance = NSAppearance(named: .darkAqua)
        default:      NSApp.appearance = nil
        }
    }

    /// "رجّع كل الإعدادات": كل اللي في البانل يرجع للافتراضي.
    /// التشغيل مع الجهاز ولغة الواجهة والإحصائيات بيفضلوا زي ما هم.
    static func resetAll() {
        let d = UserDefaults.standard
        for key in [appearance, sidebarCollapsed, showMenuBar, playSound, switchKeyboard] {
            d.removeObject(forKey: key)
        }
        KeyboardShortcuts.reset(.convert)
        applyAppearance("system")
    }
}
