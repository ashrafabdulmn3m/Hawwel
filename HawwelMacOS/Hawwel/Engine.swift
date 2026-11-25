import AppKit
import Combine
import ApplicationServices
import ServiceManagement
import KeyboardShortcuts

/// حالة آخر عملية (بتظهر في السايدبار وكارت "جرّب هنا")
enum EngineStatus: Equatable {
    case ready
    case converted
    case noSelection
    case noPermission
    case noKeyboard
}

/// بيتبعت مع كل ضغطة اختصار علشان كارت "جرّب هنا" ينوّر الكيكابس ويحدّث الخطوات.
struct ConversionEvent: Equatable {
    let id = UUID()
    let success: Bool
}

final class Engine: ObservableObject {
    @Published var trusted = AXIsProcessTrusted()
    @Published private(set) var status: EngineStatus = .ready
    @Published private(set) var lastEvent: ConversionEvent?
    @Published var launchAtLogin = (SMAppService.mainApp.status == .enabled)
    @Published var loginError = false

    let stats: Stats

    // علشان لو الاختصار اتداس مرتين ورا بعض ما يحصلش تداخل
    private var busy = false

    init(stats: Stats) {
        self.stats = stats
        KeyboardShortcuts.onKeyUp(for: .convert) { [weak self] in
            // ننتظر شوية علشان المستخدم يرفع إيده من الزراير
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.run() }
        }
    }

    // MARK: - Permission / Login

    func refreshTrust() {
        let now = AXIsProcessTrusted()
        if now != trusted { trusted = now }
        if now && status == .noPermission { status = .ready }
    }

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
            loginError = false
        } catch {
            loginError = true
        }
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    // MARK: - Conversion

    func run() {
        guard !busy else { return }
        guard AXIsProcessTrusted() else {
            trusted = false
            finish(.noPermission)
            return
        }
        // بنبنيه تاني كل مرة (سريع جداً) علشان لو المستخدم فعّل أو شال كيبورد والبرنامج شغّال
        guard let converter = LayoutConverter() else {
            finish(.noKeyboard)
            return
        }
        busy = true
        // نقرأ حالة Caps Lock والبرنامج اللي قدام قبل ما نبعت أي ضغطات
        let capsLock = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
        let front = NSWorkspace.shared.frontmostApplication
        let isPractice = front?.bundleIdentifier == Bundle.main.bundleIdentifier // كارت "جرّب هنا"

        let pb = NSPasteboard.general
        let saved = snapshot(pb)
        let adobe = front?.bundleIdentifier?.hasPrefix("com.adobe") == true

        // لازم المستخدم يرفع إيده من كل الزراير (Ctrl/⌥/⇧/⌘) قبل ما نبعت ⌘C:
        // برامج زي Adobe بتقرا الزراير اللي متداسة فعلاً، فلو Ctrl لسه متداس هتشوفها ⌃⌘C
        waitForModifiersReleased { [weak self] in
            self?.copySelection(pb, timeout: adobe ? 1.2 : 0.6) { [weak self] text in
                guard let self else { return }
                guard let text else {
                    // مفيش كلام محدد: ما نعملش حاجة ونقول للمستخدم يحدد الأول
                    self.restore(pb, saved)
                    self.busy = false
                    self.finish(.noSelection)
                    return
                }
                let toArabic = converter.isToArabic(text)
                let output = converter.convert(text, capsLock: capsLock)
                self.replace(with: output, pb, saved, front: front) {
                    self.busy = false
                    self.finish(.converted)
                    if !isPractice {
                        self.stats.record(chars: text.count, toArabic: toArabic, app: front?.localizedName)
                    }
                    self.afterConvert(toArabic: toArabic, converter: converter)
                }
            }
        }
    }

    /// بيستنى لحد ما مفيش أي زرار تعديل متداس (لحد ثانية بالكتير)
    private func waitForModifiersReleased(_ then: @escaping () -> Void, deadline: Date = Date().addingTimeInterval(1)) {
        let held = CGEventSource.flagsState(.hidSystemState)
            .intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
        if held.isEmpty || Date() > deadline {
            // مهلة صغيرة بعد ما الإيد تترفع علشان البرنامج يلحق ياخد الحدث
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: then)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            self.waitForModifiersReleased(then, deadline: deadline)
        }
    }

    private func finish(_ result: EngineStatus) {
        status = result
        lastEvent = ConversionEvent(success: result == .converted)
    }

    /// الصوت وتغيير لغة الكيبورد (من الإعدادات)
    private func afterConvert(toArabic: Bool, converter: LayoutConverter) {
        let d = UserDefaults.standard
        if d.bool(forKey: Prefs.playSound) {
            ConvertSound.play()
        }
        if d.bool(forKey: Prefs.switchKeyboard) {
            LayoutConverter.selectInputSource(id: toArabic ? converter.layoutIDs.ar : converter.layoutIDs.en)
        }
    }

    /// بيبعت ⌘C وبيستنى الكلام يوصل للـ clipboard (برامج Adobe أبطأ، فبنستناها أكتر)
    private func copySelection(_ pb: NSPasteboard, timeout: TimeInterval, _ done: @escaping (String?) -> Void) {
        let before = pb.changeCount
        press(8, .maskCommand) // Cmd+C
        let deadline = Date().addingTimeInterval(timeout)
        func check() {
            if pb.changeCount != before, let t = pb.string(forType: .string), !t.isEmpty {
                done(t)
            } else if Date() > deadline {
                done(nil)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: check)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: check)
    }

    private func replace(with text: String, _ pb: NSPasteboard, _ saved: [NSPasteboardItem],
                         front: NSRunningApplication?, completion: @escaping () -> Void) {
        let adobe = front?.bundleIdentifier?.hasPrefix("com.adobe") == true

        if adobe {
            // برامج Adobe: نرجّع الـ clipboard فوراً ونكتب النص بدل اللصق
            restore(pb, saved)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.typeText(text)
                completion()
            }
            return
        }

        pb.clearContents()
        pb.setString(text, forType: .string)
        // علشان برامج الـ clipboard history (Maccy, Raycast…) ما تحفظش النص المؤقت ده
        pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.press(9, .maskCommand) // Cmd+V
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.restore(pb, saved)
                completion()
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
    /// بيكتب النص حرف حرف (برامج Adobe بتتجاهل اللصق والأحداث اللي فيها كذا حرف مع بعض).
    /// كل حدث من غير أي زرار تعديل، علشان لو Ctrl لسه متداس ما يتحسبش اختصار.
    private func typeText(_ text: String) {
        let src = CGEventSource(stateID: .privateState)
        for ch in text {
            let units = Array(String(ch).utf16)
            for keyDown in [true, false] {
                guard let e = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: keyDown) else { continue }
                e.flags = []
                e.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
                e.post(tap: .cghidEventTap)
            }
            usleep(4000) // 4ms بين كل حرف علشان البرنامج ما يفوّتش حاجة
        }
    }

}

/// صوت التحويل: نغمتين ناعمتين وقصيرين (convert-sound.wav)، بصوت واطي.
enum ConvertSound {
    private static let sound: NSSound? = {
        guard let url = Bundle.main.url(forResource: "convert-sound", withExtension: "wav"),
              let s = NSSound(contentsOf: url, byReference: true) else { return nil }
        s.volume = 0.7
        return s
    }()

    static func play() {
        guard let sound else { return }
        sound.stop() // لو اتداس بسرعة ورا بعض، يبدأ من الأول بدل ما يتراكب
        sound.play()
    }
}
