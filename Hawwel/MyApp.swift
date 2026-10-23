import SwiftUI

@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var engine = Engine()
    @AppStorage("showMenuBar") private var showMenuBar = true
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Hawwel", id: "main") {
            ContentView().environmentObject(engine)
        }
        .windowResizability(.contentSize)

        MenuBarExtra(isInserted: $showMenuBar) {
            Button("حوّل النص المحدد") { engine.run() }
            Button("فتح Hawwel") {
                openWindow(id: "main")
                AppMode.showDock()
            }
            Divider()
            Button("خروج") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: "character.bubble")
                .onAppear {
                    AppMode.openMain = {
                        openWindow(id: "main")
                        AppMode.showDock()
                    }
                }
        }
    }
}
