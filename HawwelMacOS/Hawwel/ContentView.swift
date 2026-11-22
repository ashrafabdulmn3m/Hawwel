import SwiftUI
import AppKit
import Combine

/// التابات اللي في السايدبار
enum Tab: String, CaseIterable, Identifiable {
    case home, shortcuts, activity, settings, about
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home:      return "house"
        case .shortcuts: return "keyboard"
        case .activity:  return "chart.bar"
        case .settings:  return "gearshape"
        case .about:     return "info.circle"
        }
    }

    var title: String { L("tab.\(rawValue)") }
    var subtitle: String? { self == .about ? nil : L("sub.\(rawValue)") }
}

enum Links {
    static let website   = URL(string: "https://hawwelapp.vercel.app/")!
    static let source    = URL(string: "https://github.com/ashrafabdulmn3m/Hawwel")!
    static let reportBug = URL(string: "https://www.youtube.com/@HawwelApp")!
    static let feedback  = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSea7SjLbKyhVT8Bp3jT2pljAdNw3ymSG9_iVv-fBfg9PpUMkg/viewform")!
    static let github    = URL(string: "https://github.com/ashrafabdulmn3m")!
    static let facebook  = URL(string: "https://www.facebook.com/ashrafmn3m/")!
    static let instagram = URL(string: "https://www.instagram.com/ashrafabdulmonnem/")!
    static let youtube   = URL(string: "https://www.youtube.com/@HawwelApp")!
}

/// البانل: سايدبار + محتوى التاب + فوتر (780×560)
struct ContentView: View {
    @EnvironmentObject var engine: Engine
    @AppStorage(Prefs.language) private var language = AppLanguage.ar.rawValue
    @AppStorage(Prefs.appearance) private var appearance = "system"
    @AppStorage(Prefs.sidebarCollapsed) private var collapsed = false
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var tab: Tab

    init(initialTab: Tab = .home) {
        _tab = State(initialValue: initialTab)
    }
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var lang: AppLanguage { AppLanguage(rawValue: language) ?? .ar }

    /// أزرار النافذة (الأحمر والأصفر والأخضر) بتبقى في ناحية لغة الماك.
    /// لو السايدبار في نفس الناحية، بننزّل محتواه تحت الأزرار.
    private var sidebarUnderWindowButtons: Bool {
        let buttonsOnLeft = NSApp.userInterfaceLayoutDirection == .leftToRight
        let sidebarOnLeft = lang == .en
        return buttonsOnLeft == sidebarOnLeft
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Sidebar(tab: $tab, collapsed: collapsed, topInset: sidebarUnderWindowButtons ? 26 : 0) {
                    withAnimation(.easeInOut(duration: 0.2)) { collapsed.toggle() }
                }
                .frame(width: collapsed ? HW.sideClosed : HW.sideOpen)

                Rectangle().fill(HW.line).frame(width: 1)

                MainArea(tab: $tab)
            }
            Footer()
        }
        .frame(minWidth: HW.minWidth, idealWidth: HW.panelWidth, maxWidth: .infinity,
               minHeight: HW.minHeight, idealHeight: HW.panelHeight, maxHeight: .infinity)
        .background(HW.bg)
        .foregroundStyle(HW.ink)
        .ignoresSafeArea()
        .environment(\.layoutDirection, lang.layoutDirection)
        .environment(\.locale, lang.locale)
        .id(language) // لما اللغة تتغيّر: كل النصوص تتقري تاني
        .background(WindowConfigurator())
        .onReceive(tick) { _ in engine.refreshTrust() }
        .onChange(of: appearance) { _, mode in Prefs.applyAppearance(mode) }
        .onAppear {
            if SnapshotRenderer.active { return }
            Prefs.applyAppearance(appearance)
            if !AppMode.launchHandled {
                AppMode.launchHandled = true
                let firstRun = !UserDefaults.standard.bool(forKey: Prefs.hasLaunchedBefore)
                UserDefaults.standard.set(true, forKey: Prefs.hasLaunchedBefore)
                // مش أول مرة والمنيو بار شغّال: نخفي النافذة ونفضل في المنيو بار
                if !firstRun && AppMode.menuBarEnabled {
                    dismissWindow(id: "main")
                    return
                }
            }
            AppMode.showDock()
        }
    }
}

// MARK: - المحتوى

private struct MainArea: View {
    @Binding var tab: Tab

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(tab.title).font(HW.font(18, .bold))
                if let sub = tab.subtitle {
                    Text(sub).font(HW.font(12)).foregroundStyle(HW.muted)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, HW.contentPadding)
            .padding(.bottom, 10)

            ScrollView {
                Group {
                    switch tab {
                    case .home:      HomeTab(tab: $tab)
                    case .shortcuts: ShortcutsTab()
                    case .activity:  ActivityTab()
                    case .settings:  SettingsTab()
                    case .about:     AboutTab()
                    }
                }
                .padding(.horizontal, HW.contentPadding)
                .padding(.top, 4)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.automatic)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - السايدبار

private struct Sidebar: View {
    @Binding var tab: Tab
    let collapsed: Bool
    let topInset: CGFloat
    let toggle: () -> Void
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var recorder: ShortcutRecorder
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            brand
            VStack(spacing: 2) {
                ForEach(Tab.allCases) { t in
                    NavButton(tab: t, current: tab == t, collapsed: collapsed) { tab = t }
                }
            }
            Spacer(minLength: 0)
            stateBadge
        }
        .padding(.top, 16 + topInset)
        .padding(.horizontal, collapsed ? 10 : 12)
        .padding(.bottom, 14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(HW.side)
        .clipped()
    }

    @ViewBuilder private var brand: some View {
        if collapsed {
            VStack(spacing: 10) {
                AppLogo(size: 36, radius: 9)
                toggleButton
            }
            .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: 10) {
                AppLogo(size: 40, radius: 10)
                VStack(alignment: .leading, spacing: 0) {
                    Text(L("app.name")).font(HW.font(15, .bold)).lineLimit(1)
                    Text("v\(AppInfo.version)").font(HW.font(11)).foregroundStyle(HW.muted)
                }
                Spacer(minLength: 0)
                toggleButton
            }
            .padding(.horizontal, 4)
        }
    }

    private var toggleButton: some View {
        HoverIconButton(systemName: direction == .rightToLeft ? "sidebar.right" : "sidebar.left",
                        help: collapsed ? L("side.expand") : L("side.collapse"),
                        action: toggle)
    }

    @ViewBuilder private var stateBadge: some View {
        let ok = engine.trusted
        let label = ok ? L("side.running", recorder.compact) : L("side.needsPermission")
        HStack(spacing: 8) {
            Circle().fill(ok ? HW.ok : HW.warn).frame(width: 7, height: 7)
            if !collapsed {
                Text(label).font(HW.font(12, .semi)).lineLimit(1)
            }
        }
        .foregroundStyle(ok ? HW.ok : HW.warn)
        .padding(.vertical, collapsed ? 10 : 8)
        .padding(.horizontal, collapsed ? 0 : 10)
        .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
        .background(ok ? HW.okSoft : HW.warnSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .help(label)
    }
}

private struct NavButton: View {
    let tab: Tab
    let current: Bool
    let collapsed: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18, height: 18)
                if !collapsed {
                    Text(tab.title).font(HW.font(13, .medium)).lineLimit(1)
                }
            }
            .foregroundStyle(current ? HW.accent : (hovering ? HW.ink : HW.muted))
            .padding(.vertical, 8)
            .padding(.horizontal, collapsed ? 0 : 10)
            .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
            .background(current ? HW.accentSoft : (hovering ? HW.hover : .clear),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(collapsed ? tab.title : "")
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(current ? .isSelected : [])
    }
}

/// زرار أيقونة صغير (طي السايدبار)
struct HoverIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(hovering ? HW.ink : HW.muted)
                .frame(width: 28, height: 28)
                .background(hovering ? HW.hover : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// اللوجو في مربع أبيض
struct AppLogo: View {
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        Image(nsImage: NSImage(named: "hawwel-logo") ?? NSApp.applicationIconImage)
            .resizable()
            .scaledToFit()
            .padding(size * 0.07)
            .frame(width: size, height: size)
            .background(Color.white, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(HW.line, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

// MARK: - الفوتر

private struct Footer: View {
    var body: some View {
        HStack(spacing: 12) {
            Text(L("footer.copyright"))
                .font(HW.font(11.5))
                .foregroundStyle(HW.muted)
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                SocialButton(image: "social-facebook", name: "Facebook", url: Links.facebook)
                SocialButton(image: "social-instagram", name: "Instagram", url: Links.instagram)
                SocialButton(image: "social-github", name: "GitHub", url: Links.github)
                SocialButton(image: "social-youtube", name: "YouTube", url: Links.youtube)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: HW.footerHeight)
        .background(HW.side)
        .overlay(alignment: .top) { Rectangle().fill(HW.line).frame(height: 1) }
    }
}

private struct SocialButton: View {
    let image: String
    let name: String
    let url: URL
    @State private var hovering = false

    var body: some View {
        Button { NSWorkspace.shared.open(url) } label: {
            Image(image)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(hovering ? HW.ink : HW.muted)
                .frame(width: 28, height: 28)
                .background(hovering ? HW.hover : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(name)
        .accessibilityLabel(name)
    }
}

// MARK: - النافذة

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}

/// من غير شريط عنوان، فبنخلّي النافذة تتسحب من أي مكان فاضي فيها.
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
