import SwiftUI
import AppKit
import CoreText

/// ألوان وخطوط تصميم Hawwel (نهاري/ليلي تلقائي حسب مظهر النافذة).
enum HW {
    // MARK: - ألوان (نهاري, ليلي)
    private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hw: isDark ? dark : light)
        })
    }

    static let accent       = dyn(0x1E88E5, 0x3D9CF5)
    static let accentSoft   = dyn(0xE3F1FD, 0x1A3350)
    static let accentText   = dyn(0x1E88E5, 0x5DB1F7)
    static let ink          = dyn(0x171C2E, 0xEDF0F8)
    static let muted        = dyn(0x5F6B85, 0x9AA4BE)
    static let bg           = dyn(0xF3F5FA, 0x0F1422)
    static let card         = dyn(0xFFFFFF, 0x1A2036)
    static let cardBorder   = dyn(0xE8ECF4, 0x262E48)
    static let divider      = dyn(0xECEFF5, 0x262E48)
    static let field        = dyn(0xFAFBFE, 0x0F1422)
    static let fieldBorder  = dyn(0xC9D1E3, 0x2F3858)
    static let placeholder  = dyn(0x8B94AB, 0x6F7A96)
    static let switchOff    = dyn(0xC7CEDC, 0x3A4360)
    static let outlineBorder = dyn(0xD5DBE8, 0x323B5A)
    static let chipBg       = dyn(0xF4F7FC, 0x232B45)
    static let chipBorder   = dyn(0xC9D3E6, 0x313A58)
    static let segBg        = dyn(0xEAEFF8, 0x0F1422)
    static let warnBg       = dyn(0xE8F3FD, 0x16294A)

    static let pillOkBg     = dyn(0xE2F3E7, 0x14382A)
    static let pillOkDot    = dyn(0x2EA44F, 0x34D26B)
    static let pillOkText   = dyn(0x1B7F3B, 0x4ADE80)
    static let pillWarnBg   = dyn(0xFFF3DC, 0x3A2C10)
    static let pillWarnDot  = dyn(0xF59E0B, 0xFBBF24)
    static let pillWarnText = dyn(0x9A6200, 0xFCD34D)
    static let pillIdleBg   = dyn(0xEAEFF8, 0x232B45)
    static let pillIdleDot  = dyn(0x8A94AB, 0x8A94AB)
    static let pillIdleText = dyn(0x3B4660, 0xB8C1D9)

    // MARK: - خطوط IBM Plex Sans Arabic
    enum Weight { case regular, semi, bold }

    static func font(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        switch weight {
        case .regular: return .custom("IBMPlexSansArabic", size: size)
        case .semi:    return .custom("IBMPlexSansArabic-SmBld", size: size)
        case .bold:    return .custom("IBMPlexSansArabic-Bold", size: size)
        }
    }

    /// بنسجّل ملفات الخط اللي جوه الـ bundle (من غير ما نحتاج نعدّل Info.plist).
    static func registerFonts() {
        var urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        urls += Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension NSColor {
    convenience init(hw hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

// MARK: - مكوّنات مشتركة

extension View {
    /// كارت أبيض (أو غامق) بحدود ناعمة.
    func hwCard(padding: CGFloat = 16, fill: Color = HW.card) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(HW.cardBorder, lineWidth: 1))
    }
}

struct HWSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? HW.accent : HW.switchOff)
                    .frame(width: 46, height: 26)
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .padding(.horizontal, 3)
            }
            .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
        }
        .contentShape(Rectangle())
        .onTapGesture { configuration.isOn.toggle() }
    }
}

struct HWButtonStyle: ButtonStyle {
    enum Kind { case primary, outline }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HW.font(15, .semi))
            .foregroundStyle(kind == .primary ? Color.white : HW.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(kind == .primary ? HW.accent : HW.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(kind == .outline ? HW.outlineBorder : Color.clear, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// اختيار المظهر: نهاري / ليلي / تلقائي.
struct HWOption: Identifiable {
    let id: String
    let title: String
}

struct HWSegmented: View {
    @Binding var selection: String
    let options: [HWOption]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                Text(option.title)
                    .font(HW.font(14, .semi))
                    .foregroundStyle(selection == option.id ? Color.white : HW.muted)
                    .frame(minWidth: 78, minHeight: 32)
                    .background(selection == option.id ? HW.accent : Color.clear,
                                in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
                    .onTapGesture { selection = option.id }
            }
        }
        .padding(4)
        .background(HW.segBg, in: RoundedRectangle(cornerRadius: 12))
    }
}
