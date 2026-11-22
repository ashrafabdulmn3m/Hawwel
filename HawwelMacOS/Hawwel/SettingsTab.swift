import SwiftUI
import Combine

struct SettingsTab: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var updater: UpdaterManager
    @EnvironmentObject var recorder: ShortcutRecorder
    @AppStorage(Prefs.showMenuBar) private var showMenuBar = true
    @AppStorage(Prefs.appearance) private var appearance = "system"
    @AppStorage(Prefs.language) private var language = AppLanguage.ar.rawValue
    @AppStorage(Prefs.playSound) private var playSound = false
    @AppStorage(Prefs.switchKeyboard) private var switchKeyboard = true
    @State private var confirmReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: HW.gap) {
            GroupTitle(text: L("set.general"))
            ListCard {
                ToggleRow(title: L("set.login"),
                          detail: engine.loginError ? L("set.login.error") : nil,
                          isOn: Binding(get: { engine.launchAtLogin }, set: { engine.setLaunchAtLogin($0) }))
                RowDivider()
                ToggleRow(title: L("set.menubar"), detail: L("set.menubar.desc"), isOn: $showMenuBar)
                RowDivider()
                ListRow(title: L("set.appearance")) {
                    HWSegmented(selection: $appearance, options: [
                        SegOption(id: "light", title: L("set.appearance.light"), icon: "sun.max"),
                        SegOption(id: "dark", title: L("set.appearance.dark"), icon: "moon"),
                        SegOption(id: "system", title: L("set.appearance.system"), icon: "display"),
                    ])
                }
                RowDivider()
                ListRow(title: L("set.language")) {
                    HWSegmented(selection: $language, options: [
                        SegOption(id: AppLanguage.ar.rawValue, title: "عربي"),
                        SegOption(id: AppLanguage.en.rawValue, title: "English"),
                    ])
                }
            }

            GroupTitle(text: L("set.conversion"))
            ListCard {
                ToggleRow(title: L("set.sound"), detail: L("set.sound.desc"), isOn: $playSound)
                    .onChange(of: playSound) { _, on in if on { ConvertSound.play() } } // تسمعه أول ما تفعّله
                RowDivider()
                ToggleRow(title: L("set.switchKb"), detail: L("set.switchKb.desc"), isOn: $switchKeyboard)
            }

            GroupTitle(text: L("set.updates"))
            ListCard {
                ListRow(title: L("set.check"), detail: checkDetail) {
                    Button(L("set.check.now")) { updater.checkForUpdates() }
                        .buttonStyle(HWButtonStyle(kind: .primary))
                        .disabled(!updater.canCheckForUpdates)
                }
                RowDivider()
                ToggleRow(title: L("set.autoCheck"), detail: L("set.autoCheck.desc"),
                          isOn: Binding(get: { updater.automaticallyChecks }, set: { updater.setAutomaticChecks($0) }))
                RowDivider()
                ToggleRow(title: L("set.autoInstall"), detail: L("set.autoInstall.desc"),
                          isOn: Binding(get: { updater.automaticallyDownloads }, set: { updater.setAutomaticDownloads($0) }))
                    .disabled(!updater.automaticallyChecks)
                    .opacity(updater.automaticallyChecks ? 1 : 0.5)
            }

            HStack {
                Button(L("set.resetAll")) { confirmReset = true }
                    .buttonStyle(HWButtonStyle(kind: .ghost))
                Spacer(minLength: 8)
                Button(L("set.quit")) { NSApplication.shared.terminate(nil) }
                    .buttonStyle(HWButtonStyle(kind: .danger))
            }
            .padding(.top, 4)
        }
        .confirmationDialog(L("set.resetAll.confirm"), isPresented: $confirmReset) {
            Button(L("set.resetAll"), role: .destructive) {
                Prefs.resetAll()
                recorder.reload()
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("set.resetAll.confirmDesc"))
        }
    }

    /// "عندك v2.0.0 · آخر فحص من ساعتين"
    private var checkDetail: String {
        var s = L("set.check.version", AppInfo.version)
        if let last = updater.lastCheck {
            let f = RelativeDateTimeFormatter()
            f.locale = AppLanguage.current.locale
            f.unitsStyle = .full
            s += " · " + L("set.check.last", f.localizedString(for: last, relativeTo: Date()))
        }
        return s
    }
}
