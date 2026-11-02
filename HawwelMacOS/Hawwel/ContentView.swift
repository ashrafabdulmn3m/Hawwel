import SwiftUI
import KeyboardShortcuts
import Combine

struct ContentView: View {
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("appearance") private var appearance = "auto" // light | dark | auto
    @Environment(\.dismissWindow) private var dismissWindow // last edit 22oct
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var updater: UpdaterManager
    @State private var testText = ""
    @State private var shortcut: KeyboardShortcuts.Shortcut? = KeyboardShortcuts.getShortcut(for: .convert)
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    // أجزاء الاختصار كـ "كابسات": ⌃ + ⌥ + K
    private var chips: [String] {
        guard let s = shortcut else { return [] }
        let mods: Set<Character> = ["⌃", "⌥", "⇧", "⌘"]
        var out: [String] = []
        var key = ""
        for ch in s.description {
            if mods.contains(ch) { out.append(String(ch)) } else { key.append(ch) }
        }
        if !key.isEmpty { out.append(key) }
        return out
    }

    // شكل الحالة (جاهز ●)
    private var statusText: String {
        engine.status
            .replacingOccurrences(of: "⚠️", with: "")
            .replacingOccurrences(of: "✅", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    private var statusColors: (bg: Color, dot: Color, text: Color) {
        let s = engine.status
        if s.hasPrefix("⚠️") { return (HW.pillWarnBg, HW.pillWarnDot, HW.pillWarnText) }
        if s.hasPrefix("✅") || s.hasPrefix("جاهز") { return (HW.pillOkBg, HW.pillOkDot, HW.pillOkText) }
        return (HW.pillIdleBg, HW.pillIdleDot, HW.pillIdleText)
    }

    private var logo: NSImage {
        NSImage(named: "hawwel-logo") ?? NSApp.applicationIconImage
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            if !engine.trusted { permissionCard }

            shortcutCard
            tryCard
            settingsCard
            footer
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(width: 460)
        .background(HW.bg)
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(colorScheme)
        .onReceive(tick) { _ in engine.trusted = AXIsProcessTrusted() }
        .onAppear {
            if !AppMode.launchHandled {
                AppMode.launchHandled = true
                let firstRun = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                // مش أول مرة والمنيو بار شغّال: نخفي النافذة ونفضل في المنيو بار
                if !firstRun && AppMode.menuBarEnabled {
                    dismissWindow(id: "main")
                    return
                }
            }
            AppMode.showDock()
        } //last edit on appear 22oct
    }

    // MARK: - الأجزاء

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: logo)
                .resizable()
                .scaledToFit()
                .padding(4)
                .frame(width: 52, height: 52)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hawwel - حوّل")
                    .font(HW.font(24, .bold))
                    .foregroundStyle(HW.ink)
                Text("حوّل الكلام المكتوب بالكيبورد الغلط بضغطة اختصار")
                    .font(HW.font(13))
                    .foregroundStyle(HW.muted)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("الصلاحية مش مفعّلة")
                .font(HW.font(15, .semi))
                .foregroundStyle(HW.ink)
            Text("Hawwel محتاج صلاحية Accessibility علشان يقدر يحوّل النص المحدد.")
                .font(HW.font(13))
                .foregroundStyle(HW.muted)
            Button("فعّلها") {
                engine.requestPermission()
                engine.openAccessibilitySettings()
            }
            .buttonStyle(HWButtonStyle())
        }
        .hwCard(fill: HW.warnBg)
    }

    private var shortcutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("الاختصار")
                .font(HW.font(14, .semi))
                .foregroundStyle(HW.ink)
            HStack {
                HStack(spacing: 6) {
                    if chips.isEmpty {
                        Text("لسه مفيش اختصار")
                            .font(HW.font(14))
                            .foregroundStyle(HW.muted)
                    }
                    ForEach(Array(chips.enumerated()), id: \.offset) { index, chip in
                        if index > 0 {
                            Text("+").font(HW.font(16)).foregroundStyle(HW.muted)
                        }
                        Text(chip)
                            .font(HW.font(16, .semi))
                            .foregroundStyle(HW.ink)
                            .frame(minWidth: 42, minHeight: 34)
                            .padding(.horizontal, 6)
                            .background(HW.chipBg, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(HW.chipBorder, lineWidth: 1))
                    }
                }
                .environment(\.layoutDirection, .leftToRight)

                Spacer(minLength: 8)

                // مسجّل الاختصار الأصلي من مكتبة KeyboardShortcuts (بيغيّر الاختصار)
                KeyboardShortcuts.Recorder("", name: .convert) { newShortcut in
                    shortcut = newShortcut
                }
                .environment(\.layoutDirection, .leftToRight)
                .fixedSize()
            }
        }
        .hwCard()
    }

    private var tryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("جرّب هنا")
                .font(HW.font(14, .semi))
                .foregroundStyle(HW.ink)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $testText)
                    .font(HW.font(16))
                    .foregroundStyle(HW.ink)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                if testText.isEmpty {
                    Text("اكتب بالكيبورد الغلط، حدده، واضغط الاختصار")
                        .font(HW.font(15))
                        .foregroundStyle(HW.placeholder)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 70)
            .background(HW.field, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(HW.fieldBorder, lineWidth: 1))

            HStack {
                Text("اكتب، حدده، واضغط الاختصار")
                    .font(HW.font(13))
                    .foregroundStyle(HW.muted)
                Spacer()
                HStack(spacing: 8) {
                    Circle().fill(statusColors.dot).frame(width: 8, height: 8)
                    Text(statusText)
                        .font(HW.font(13, .semi))
                        .foregroundStyle(statusColors.text)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(statusColors.bg, in: Capsule())
                .frame(maxWidth: 230)
            }
        }
        .hwCard()
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("المظهر").font(HW.font(15)).foregroundStyle(HW.ink)
                Spacer()
                HWSegmented(selection: $appearance, options: [
                    HWOption(id: "light", title: "نهاري"),
                    HWOption(id: "dark", title: "ليلي"),
                    HWOption(id: "auto", title: "تلقائي")
                ])
            }
            .frame(minHeight: 50)

            Rectangle().fill(HW.divider).frame(height: 1)

            Toggle(isOn: Binding(
                get: { engine.launchAtLogin },
                set: { engine.setLaunchAtLogin($0) }
            )) {
                Text("شغّل Hawwel مع بداية الجهاز").font(HW.font(15)).foregroundStyle(HW.ink)
            }
            .toggleStyle(HWSwitchStyle())
            .frame(minHeight: 48)

            Rectangle().fill(HW.divider).frame(height: 1)

            Toggle(isOn: $showMenuBar) {
                Text("أظهر Hawwel في المنيو بار").font(HW.font(15)).foregroundStyle(HW.ink)
            }
            .toggleStyle(HWSwitchStyle())
            .frame(minHeight: 48)

            Rectangle().fill(HW.divider).frame(height: 1)

            Toggle(isOn: Binding(
                get: { updater.automaticallyChecks },
                set: { updater.setAutomaticChecks($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("دوّر على التحديثات تلقائياً").font(HW.font(15)).foregroundStyle(HW.ink)
                    Text("بيتصل بـ GitHub بس").font(HW.font(12)).foregroundStyle(HW.muted)
                }
            }
            .toggleStyle(HWSwitchStyle())
            .frame(minHeight: 52)
        }
        .hwCard(padding: 16)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("دوّر على تحديث") { updater.checkForUpdates() }
                .buttonStyle(HWButtonStyle())
                .disabled(!updater.canCheckForUpdates)
            Button("خروج من Hawwel") { NSApplication.shared.terminate(nil) }
                .buttonStyle(HWButtonStyle(kind: .outline))
            Spacer()
            Text("v\(appVersion)")
                .font(HW.font(15))
                .foregroundStyle(HW.muted)
                .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.top, 4)
    }
}
