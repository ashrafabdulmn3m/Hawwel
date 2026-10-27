import AppKit
import Combine
import ApplicationServices
import ServiceManagement
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let convert = Self("convert", initial: .init(.k, modifiers: [.control]))
}

final class Engine: ObservableObject {
    @Published var trusted = AXIsProcessTrusted()
    @Published var status = "جاهز"
    @Published var launchAtLogin = (SMAppService.mainApp.status == .enabled)

    private let converter = LayoutConverter()

    init() {
        KeyboardShortcuts.onKeyUp(for: .convert) { [weak self] in
            // ننتظر شوية علشان المستخدم يرفع إيده من الزراير
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.run() }
        }
    }

    // MARK: - Permission / Login

    func requestPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            status = "تعذّر تغيير إعداد التشغيل مع الجهاز"
        }
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    // MARK: - Conversion

    func run() {
        guard AXIsProcessTrusted() else {
            trusted = false
            status = "⚠️ الصلاحية مش مفعّلة"
            return
        }
        guard let converter else {
            status = "⚠️ الكيبورد مش لاقيه (US أو Arabic-PC)"
            return
        }
        // نقرأ حالة Caps Lock قبل ما نبعت أي ضغطات
        let capsLock = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)

        let pb = NSPasteboard.general
        let saved = snapshot(pb)

        copySelection(pb) { [weak self] text in
            guard let self else { return }
            if let text {
                self.replace(with: converter.convert(text, capsLock: capsLock), pb, saved)
                return
            }
            // مفيش تحديد: حدد آخر كلمة (⌥⇧←)
            self.press(123, [.maskAlternate, .maskShift])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.copySelection(pb) { text in
                    guard let text else {
                        self.status = "مفيش نص محدد"
                        self.restore(pb, saved)
                        return
                    }
                    self.replace(with: converter.convert(text, capsLock: capsLock), pb, saved)
                }
            }
        }
    }

    private func copySelection(_ pb: NSPasteboard, _ done: @escaping (String?) -> Void) {
        let before = pb.changeCount
        press(8, .maskCommand) // Cmd+C
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if pb.changeCount != before, let t = pb.string(forType: .string), !t.isEmpty {
                done(t)
            } else {
                done(nil)
            }
        }
    }

    private func replace(with text: String, _ pb: NSPasteboard, _ saved: [NSPasteboardItem]) {
        let adobe = NSWorkspace.shared.frontmostApplication?
            .bundleIdentifier?.hasPrefix("com.adobe") == true

        if adobe {
            // برامج Adobe: نرجّع الـ clipboard فوراً ونكتب النص بدل اللصق
            restore(pb, saved)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.typeText(text)
                self.status = "✅ اتحول: \(text.prefix(30))"
            }
            return
        }

        pb.clearContents()
        pb.setString(text, forType: .string)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.press(9, .maskCommand) // Cmd+V
            self.status = "✅ اتحول: \(text.prefix(30))"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.restore(pb, saved)
            }
        }
    }
    private func snapshot(_ pb: NSPasteboard) -> [NSPasteboardItem] {
        (pb.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    private func restore(_ pb: NSPasteboard, _ saved: [NSPasteboardItem]) {
        pb.clearContents()
        pb.writeObjects(saved)
    }

    private func press(_ key: CGKeyCode, _ flags: CGEventFlags) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
    private func typeText(_ text: String) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let utf16 = Array(text.utf16)
        var i = 0
        while i < utf16.count {
            let chunk = Array(utf16[i..<min(i + 20, utf16.count)])
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
            down?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
            down?.post(tap: .cghidEventTap)
            let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            up?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
            up?.post(tap: .cghidEventTap)
            i += 20
        }
    }
}
