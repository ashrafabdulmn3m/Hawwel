import SwiftUI
import AppKit

/// ألوان ومقاسات تصميم Hawwel 2.0 (فاتح/داكن تلقائي حسب مظهر النافذة).
enum HW {
    // MARK: - ألوان (فاتح, داكن)
    private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hw: isDark ? dark : light)
        })
    }

    static let bg          = dyn(0xF3F5F9, 0x131829)
    static let side        = dyn(0xE8ECF4, 0x0E1222)
    static let card        = dyn(0xFFFFFF, 0x1B2237)
    static let line        = dyn(0xDCE2EC, 0x29324D)
    static let ink         = dyn(0x141B2D, 0xECEFF7)
    static let muted       = dyn(0x66708A, 0x8C95B0)
    static let accent      = dyn(0x2F86E4, 0x5B9CF0)
    static let accentSoft  = dyn(0xE2EDFC, 0x1D3150)
    static let ok          = dyn(0x2E9D57, 0x5BC27E)
    static let okSoft      = dyn(0xE0F3E6, 0x163222)
    static let warn        = dyn(0xB8770C, 0xE3AC40)
    static let warnSoft    = dyn(0xFBF0DC, 0x3A2D12)
    static let field       = dyn(0xF6F8FB, 0x0D1121)
    static let key         = dyn(0xF4F6FA, 0x232B45)
    static let danger      = dyn(0xD9534F, 0xF07470)
    static let hover       = dyn(0x141B2D, 0xECEFF7).opacity(0.06)

    // MARK: - مقاسات
    // الحجم الطبيعي أول ما النافذة تفتح، وأصغر حجم ممكن (المستخدم يقدر يكبّرها براحته)
    static let panelWidth: CGFloat = 780
    static let panelHeight: CGFloat = 560
    static let minWidth: CGFloat = 660
    static let minHeight: CGFloat = 460
    static let sideOpen: CGFloat = 196
    static let sideClosed: CGFloat = 64
    static let footerHeight: CGFloat = 44
    static let contentPadding: CGFloat = 22
    static let gap: CGFloat = 12

    // MARK: - خطوط (خط النظام: SF Arabic للعربي و SF Pro للإنجليزي)
    enum Weight { case regular, medium, semi, bold }

    static func font(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        switch weight {
        case .regular: return .system(size: size)
        case .medium:  return .system(size: size, weight: .medium)
        case .semi:    return .system(size: size, weight: .semibold)
        case .bold:    return .system(size: size, weight: .bold)
        }
    }

    /// الأرقام والكيكابس: ثابتة العرض ودايماً LTR
    static func number(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
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

// MARK: - الكارت

extension View {
    /// كارت: radius 12، padding 14×16، حدود رفيعة.
    func hwCard(fill: Color = HW.card, border: Color = HW.line, padding: EdgeInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(border, lineWidth: 1))
    }
}

/// عنوان الكارت
struct CardTitle: View {
    let text: String
    var body: some View {
        Text(text).font(HW.font(13, .semi)).foregroundStyle(HW.ink)
    }
}

/// عنوان مجموعة صغير فوق الكروت (عام، التحويل، التحديثات…)
struct GroupTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(HW.font(11, .semi))
            .foregroundStyle(HW.muted)
            .padding(.horizontal, 4)
            .padding(.bottom, -4)
    }
}

// MARK: - الكيكابس

struct Keycaps: View {
    enum Size { case small, regular, large }
    let parts: [String]
    var size: Size = .regular
    var lit = false

    private var metrics: (minW: CGFloat, h: CGFloat, font: CGFloat, radius: CGFloat, pad: CGFloat) {
        switch size {
        case .small:   return (24, 22, 11.5, 5, 6)
        case .regular: return (34, 32, 14, 7, 9)
        case .large:   return (44, 42, 17, 9, 9)
        }
    }

    var body: some View {
        let m = metrics
        HStack(spacing: 6) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index > 0 {
                    Text("+").font(HW.font(12)).foregroundStyle(HW.muted)
                }
                Text(part)
                    .font(.system(size: m.font, weight: .semibold))
                    .foregroundStyle(lit ? Color.white : HW.ink)
                    .padding(.horizontal, m.pad)
                    .frame(minWidth: m.minW, minHeight: m.h)
                    .background(lit ? HW.accent : HW.key, in: RoundedRectangle(cornerRadius: m.radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: m.radius, style: .continuous).stroke(lit ? HW.accent : HW.line, lineWidth: 1))
                    .overlay(alignment: .bottom) {
                        // الضل اللي تحت الكيكاب
                        RoundedRectangle(cornerRadius: m.radius, style: .continuous)
                            .fill(HW.ink.opacity(lit ? 0 : 0.10))
                            .frame(height: 2)
                            .padding(.horizontal, 1)
                            .mask(RoundedRectangle(cornerRadius: m.radius, style: .continuous))
                    }
                    .offset(y: lit ? 1 : 0)
            }
        }
        .environment(\.layoutDirection, .leftToRight) // الكيكابس دايماً LTR
        .animation(.easeOut(duration: 0.08), value: lit)
    }
}

// MARK: - البيلز (الحالة)

struct Pill: View {
    enum Kind { case ok, warn, info, soon }
    let text: String
    var kind: Kind = .ok
    var showDot = true

    private var colors: (bg: Color, fg: Color) {
        switch kind {
        case .ok:   return (HW.okSoft, HW.ok)
        case .warn: return (HW.warnSoft, HW.warn)
        case .info: return (HW.accentSoft, HW.accent)
        case .soon: return (HW.ink.opacity(0.07), HW.muted)
        }
    }

    var body: some View {
        let c = colors
        HStack(spacing: 6) {
            if showDot { Circle().fill(c.fg).frame(width: 7, height: 7) }
            Text(text).font(HW.font(11.5, .semi)).lineLimit(1)
        }
        .foregroundStyle(c.fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(c.bg, in: Capsule())
        .fixedSize()
    }
}

// MARK: - الأزرار

struct HWButtonStyle: ButtonStyle {
    enum Kind { case normal, primary, ghost, danger }
    var kind: Kind = .normal

    func makeBody(configuration: Configuration) -> some View {
        HWButtonBody(configuration: configuration, kind: kind)
    }

    private struct HWButtonBody: View {
        let configuration: Configuration
        let kind: Kind
        @Environment(\.isEnabled) private var enabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(HW.font(12.5, .medium))
                .lineLimit(1)
                .foregroundStyle(foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(border, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
                .onHover { hovering = $0 }
                .fixedSize()
        }

        private var foreground: Color {
            switch kind {
            case .primary: return .white
            case .danger:  return HW.danger
            default:       return HW.ink
            }
        }
        private var background: Color {
            switch kind {
            case .primary: return HW.accent
            case .ghost:   return hovering ? HW.hover : .clear
            default:       return hovering ? HW.field : HW.card
            }
        }
        private var border: Color {
            switch kind {
            case .primary: return HW.accent
            case .ghost:   return .clear
            default:       return HW.line
            }
        }
    }
}

// MARK: - السويتش

struct HWSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 14) {
            configuration.label
            Spacer(minLength: 0)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? HW.accent : HW.ink.opacity(0.18))
                    .frame(width: 38, height: 22)
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    .frame(width: 16, height: 16)
                    .padding(.horizontal, 3)
            }
            .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
            .onTapGesture { configuration.isOn.toggle() }
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(configuration.isOn ? "1" : "0")
        }
        .contentShape(Rectangle())
    }
}

// MARK: - اختيار من كذا حاجة (المظهر / اللغة)

struct SegOption: Identifiable {
    let id: String
    let title: String
    var icon: String? = nil
}

struct HWSegmented: View {
    @Binding var selection: String
    let options: [SegOption]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                let on = selection == option.id
                Button {
                    selection = option.id
                } label: {
                    HStack(spacing: 5) {
                        if let icon = option.icon {
                            Image(systemName: icon).font(.system(size: 11, weight: .medium))
                        }
                        Text(option.title).font(HW.font(12, on ? .medium : .regular)).lineLimit(1)
                    }
                    .foregroundStyle(on ? HW.ink : HW.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(on ? HW.card : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: .black.opacity(on ? 0.12 : 0), radius: 1, y: 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(HW.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(HW.line, lineWidth: 1))
        .fixedSize()
    }
}

// MARK: - صف في قايمة (اسم + وصف + حاجة على الطرف التاني)

struct ListRow<Trailing: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(HW.font(13, .medium)).foregroundStyle(HW.ink)
                if let detail {
                    Text(detail).font(HW.font(11.5)).foregroundStyle(HW.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 10)
        .frame(minHeight: 44)
    }
}

/// صف بسويتش
struct ToggleRow: View {
    let title: String
    var detail: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(HW.font(13, .medium)).foregroundStyle(HW.ink)
                if let detail {
                    Text(detail).font(HW.font(11.5)).foregroundStyle(HW.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(HWSwitchStyle())
        .padding(.vertical, 10)
        .frame(minHeight: 44)
    }
}

/// كارت فيه صفوف (حط RowDivider بين كل صف والتاني)
struct ListCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) { content() }
            .hwCard(padding: .init(top: 2, leading: 16, bottom: 2, trailing: 16))
    }
}

/// الخط الرفيع بين الصفوف
struct RowDivider: View {
    var body: some View { Rectangle().fill(HW.line).frame(height: 1) }
}
