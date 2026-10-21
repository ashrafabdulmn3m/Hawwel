import SwiftUI
import KeyboardShortcuts
import Combine

struct ContentView: View {
    @AppStorage("showMenuBar") private var showMenuBar = true
    @EnvironmentObject var engine: Engine
    @State private var testText = ""
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
        }
        .padding(24)
        .frame(width: 440)
        .onReceive(tick) { _ in engine.trusted = AXIsProcessTrusted() }
    }
}
