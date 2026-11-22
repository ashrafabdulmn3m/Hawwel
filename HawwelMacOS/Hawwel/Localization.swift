import Foundation
import SwiftUI

/// لغة الواجهة (مستقلة عن لغة الماك). النصوص كلها في Localizable.xcstrings.
enum AppLanguage: String, CaseIterable {
    case ar, en

    /// للمعاينة بس (SnapshotRenderer)
    static var override: AppLanguage?

    static var current: AppLanguage {
        if let override { return override }
        return AppLanguage(rawValue: UserDefaults.standard.string(forKey: Prefs.language) ?? "") ?? .ar
    }

    var layoutDirection: LayoutDirection { self == .ar ? .rightToLeft : .leftToRight }
    // أرقام إنجليزية حتى في العربي (زي التصميم)
    var locale: Locale { Locale(identifier: self == .ar ? "ar_EG@numbers=latn" : "en_US") }

    /// الـ bundle بتاع اللغة (ar.lproj / en.lproj) علشان نقرا منه النصوص
    var bundle: Bundle {
        if let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
           let b = Bundle(path: path) { return b }
        return .main
    }
}

/// نص مترجم حسب لغة الواجهة الحالية.
func L(_ key: String) -> String {
    let lang = AppLanguage.current
    let s = lang.bundle.localizedString(forKey: key, value: key, table: nil)
    // علامة RLM في الأول: الجملة العربي تفضل من اليمين للشمال حتى لو بدأت بكلمة إنجليزي (Hawwel…)
    return lang == .ar ? "\u{200F}" + s : s
}


/// نص مترجم فيه قيم (%@ / %d).
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), locale: AppLanguage.current.locale, arguments: args)
}

/// الأرقام دايماً بالأرقام الإنجليزية (1,284) في اللغتين، زي التصميم.
enum Num {
    private static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        return f
    }()

    static func grouped(_ n: Int) -> String { grouped.string(from: NSNumber(value: n)) ?? "\(n)" }

    /// 486 / 1.2K / 52K
    static func compact(_ n: Int) -> String {
        switch n {
        case ..<1000: return "\(n)"
        case ..<10_000:
            let v = (Double(n) / 1000 * 10).rounded() / 10
            return v == v.rounded() ? "\(Int(v))K" : String(format: "%.1fK", v)
        case ..<1_000_000: return "\(n / 1000)K"
        default: return String(format: "%.1fM", Double(n) / 1_000_000)
        }
    }
}
