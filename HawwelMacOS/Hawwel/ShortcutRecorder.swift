import AppKit
import Combine
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let convert = Self("convert", initial: .init(.k, modifiers: [.control]))
}

/// تسجيل اختصار جديد من صف "غيّر" في تاب الاختصارات.
/// الحالات: عادي، بيسجّل (Esc للإلغاء)، تعارض مع اختصار بيستخدمه الماك.
final class ShortcutRecorder: ObservableObject {
    enum State: Equatable {
        case idle
        case recording
        case conflict(KeyboardShortcuts.Shortcut)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var shortcut: KeyboardShortcuts.Shortcut? = KeyboardShortcuts.getShortcut(for: .convert)
    /// الزراير اللي المستخدم ضاغط عليها دلوقتي وهو بيسجّل
    @Published private(set) var liveModifiers: NSEvent.ModifierFlags = []

    private var monitor: Any?
    private static let modifierMask: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    var isRecording: Bool { state != .idle }

    /// أجزاء الاختصار الحالي كـ كيكابس: ["⌃", "K"]
    var parts: [String] { Self.parts(of: shortcut) }

    /// النص المختصر زي "⌃K" (للسايدبار)
    var compact: String { shortcut?.description ?? "" }

    func start() {
        guard monitor == nil else { return }
        KeyboardShortcuts.disable(.convert) // علشان الاختصار الحالي ما يشتغلش وإحنا بنسجّل
        state = .recording
        liveModifiers = []
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handle(event)
            return nil
        }
    }

    func cancel() {
        guard monitor != nil else { return }
        stop()
    }

    func resetToDefault() {
        cancel()
        KeyboardShortcuts.reset(.convert)
        shortcut = KeyboardShortcuts.getShortcut(for: .convert)
    }

    /// بعد "رجّع كل الإعدادات"
    func reload() {
        shortcut = KeyboardShortcuts.getShortcut(for: .convert)
    }

    private func handle(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection(Self.modifierMask)
        if event.type == .flagsChanged {
            liveModifiers = mods
            return
        }
        // Esc لوحده = إلغاء
        if event.keyCode == 53 && mods.isEmpty {
            stop()
            return
        }
        // لازم ⌃ أو ⌥ أو ⌘ مع المفتاح (Shift لوحده بيكتب حروف كبيرة)
        guard !mods.intersection([.control, .option, .command]).isEmpty,
              let new = KeyboardShortcuts.Shortcut(event: event) else {
            NSSound.beep()
            return
        }
        if new.isTakenBySystem {
            state = .conflict(new)
            return
        }
        KeyboardShortcuts.setShortcut(new, for: .convert)
        shortcut = new
        stop()
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        KeyboardShortcuts.enable(.convert)
        state = .idle
        liveModifiers = []
    }

    // MARK: - كيكابس

    static func parts(of shortcut: KeyboardShortcuts.Shortcut?) -> [String] {
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

    /// رموز الزراير اللي متضغطة بترتيب أبل: ⌃ ⌥ ⇧ ⌘
    static func symbols(_ m: NSEvent.ModifierFlags) -> [String] {
        var out: [String] = []
        if m.contains(.control) { out.append("⌃") }
        if m.contains(.option) { out.append("⌥") }
        if m.contains(.shift) { out.append("⇧") }
        if m.contains(.command) { out.append("⌘") }
        return out
    }
}
