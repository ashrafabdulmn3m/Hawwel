import SwiftUI
import KeyboardShortcuts
import Combine

struct ContentView: View {
    @AppStorage("showMenuBar") private var showMenuBar = true
    @Environment(\.dismissWindow) private var dismissWindow // last edit 22oct
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var updater: UpdaterManager
    @State private var testText = ""
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hawwel").font(.largeTitle.bold())
                Text("حوّل الكلام المكتوب بالكيبورد الغلط بضغطة اختصار")
                    .foregroundStyle(.secondary)
            }

            GroupBox("الصلاحية") {
                HStack {
                    Image(systemName: engine.trusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(engine.trusted ? .green : .red)
                    Text(engine.trusted ? "مفعّلة" : "مش مفعّلة")
                    Spacer()
                    if !engine.trusted {
                        Button("فعّلها") {
                            engine.requestPermission()
                            engine.openAccessibilitySettings()
                        }
                    }
                }
                .padding(6)
            }

            GroupBox("الاختصار") {
                KeyboardShortcuts.Recorder("اختار اختصارك:", name: .convert)
                    .padding(6)
            }

            GroupBox("جرّب هنا") {
                VStack(alignment: .leading) {
                    TextField("اكتب بالكيبورد الغلط، حدده، واضغط الاختصار", text: $testText)
                    Text(engine.status).font(.caption).foregroundStyle(.secondary)
                }
                .padding(6)
            }

            Toggle("شغّل Hawwel مع بداية الجهاز", isOn: Binding(
                get: { engine.launchAtLogin },
                set: { engine.setLaunchAtLogin($0) }
            ))
            Toggle("أظهر Hawwel في المنيو بار", isOn: $showMenuBar)
            Toggle("دوّر على التحديثات تلقائياً", isOn: Binding(
                get: { updater.automaticallyChecks },
                set: { updater.setAutomaticChecks($0) }
            ))

            HStack {
                Text("الإصدار \(appVersion)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("دوّر على تحديث") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
        }
        .padding(24)
        .frame(width: 440)
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
}
