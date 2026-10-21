import SwiftUI

@main
struct MyApp: App {
    @StateObject private var engine = Engine()
    @AppStorage("showMenuBar") private var showMenuBar = true
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView().environmentObject(engine)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Hawwel", systemImage: "character.bubble", isInserted: $showMenuBar) {
            Button("حوّل النص المحدد") { engine.run() }
            Button("فتح Hawwel") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button("خروج") { NSApplication.shared.terminate(nil) }
        }
    }
}
