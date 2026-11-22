//
//  LayoutConverter.swift
//  Hawwel
//
//  Created by ashraf on 21/10/2026.
//

import Carbon

final class LayoutConverter {
    private var enToAr: [String: String] = [:]
    private var arToEn: [String: String] = [:]
    /// الكيبوردين اللي اتبنى عليهم الجدول (علشان نعرف نبنيه تاني لو المستخدم غيّر الكيبورد)
    private(set) var layoutIDs: (en: String, ar: String) = ("", "")

    init?() {
        // الكيبوردات اللي المستخدم مفعّلها في System Settings، وبعدها كل اللي متسطّب على الماك
        let enabled = Self.allSourceIDs(includeAllInstalled: false)
        let installed = Self.allSourceIDs(includeAllInstalled: true)

        let (enID, arID) = Self.pickLayouts(enabled: enabled, installed: installed)

        guard let enID, let arID,
              let en = Self.layoutData(id: enID),
              let ar = Self.layoutData(id: arID) else {
            print("Could not find an English or Arabic layout")
            return nil
        }
        self.layoutIDs = (enID, arID)

        // مفاتيح الكيبورد الرئيسية (ما عدا Return و Tab و Space)
        for keyCode in 0...50 where ![36, 48, 49].contains(keyCode) {
            for shift in [false, true] {
                guard let e = Self.char(keyCode, shift, en),
                      let a = Self.char(keyCode, shift, ar) else { continue }
                enToAr[e] = a
                arToEn[a] = e
            }
        }
    }

    /// يحوّل النص تلقائياً حسب الاتجاه.
    /// capsLock: حالة Caps Lock وقت التحويل، علشان الحروف الكبيرة بسببه ما تتحوّلش كأنها Shift.
    func convert(_ text: String, capsLock: Bool = false) -> String {
        if isToArabic(text) { return map(fixCapsLock(text, capsLock: capsLock), enToAr) }
        return map(text, arToEn)
    }

    /// النص هيتحوّل لعربي؟ (لو أغلب حروفه لاتيني)
    func isToArabic(_ text: String) -> Bool {
        let latin = text.unicodeScalars.filter { $0.properties.isAlphabetic && $0.isASCII }.count
        let arabic = text.unicodeScalars.filter { (0x0600...0x06FF).contains($0.value) }.count
        return latin > arabic
    }

    /// بيغيّر كيبورد الماك للكيبورد ده، لو المستخدم مفعّله.
    static func selectInputSource(id: String) {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
              let src = list.first else { return }
        TISSelectInputSource(src)
    }

    /// لو Caps Lock شغّال: كل حرف لاتيني ظاهر بعكس الـ Shift الحقيقي، فنقلب حالته.
    /// لو مقفول لكن كل الحروف كبيرة (والمستخدم قفله بعد الكتابة): نصغّرها.
    private func fixCapsLock(_ text: String, capsLock: Bool) -> String {
        if capsLock { return transformASCII(text, swap: true) }

        let letters = text.filter { $0.isASCII && $0.isLetter }
        let upper = letters.filter { $0.isUppercase }.count
        let lower = letters.count - upper
        return (upper >= 2 && lower == 0) ? transformASCII(text, swap: false) : text
    }

    // swap = true: يقلب حالة الحروف اللاتينية، swap = false: يصغّر الكبيرة بس (ASCII فقط)
    private func transformASCII(_ text: String, swap: Bool) -> String {
        String(text.map { c -> Character in
            guard c.isASCII, c.isLetter else { return c }
            if c.isUppercase { return Character(c.lowercased()) }
            return swap ? Character(c.uppercased()) : c
        })
    }

    private func map(_ text: String, _ table: [String: String]) -> String {
        let chars = Array(text)
        var out = ""
        var i = 0
        while i < chars.count {
            // نجرب حرفين الأول (علشان "لا")
            if i + 1 < chars.count, let m = table[String(chars[i...i+1])] {
                out += m; i += 2; continue
            }
            out += table[String(chars[i])] ?? String(chars[i])
            i += 1
        }
        return out
    }

    // MARK: - Helpers

    /// يختار الكيبورد الإنجليزي والعربي: المفعّل الأول، وبعدين المتسطّب.
    static func pickLayouts(enabled: [String], installed: [String]) -> (en: String?, ar: String?) {
        // الإنجليزي: US الأول، وبعدين ABC
        let isUS: (String) -> Bool = { $0 == "com.apple.keylayout.US" }
        let isABC: (String) -> Bool = { $0 == "com.apple.keylayout.ABC" }
        // العربي: Arabic-PC الأول، وبعدين أي كيبورد عربي تاني (Arabic، Arabic-QWERTY…)
        let isArabicPC: (String) -> Bool = { $0 == "com.apple.keylayout.ArabicPC" }
        let isArabic: (String) -> Bool = { $0.hasPrefix("com.apple.keylayout.Arabic") }

        // نفضّل اللي المستخدم بيكتب بيه فعلاً، ولو مش مفعّل نرجع للمتسطّب
        let en = enabled.first(where: isUS) ?? enabled.first(where: isABC)
            ?? installed.first(where: isUS) ?? installed.first(where: isABC)
        let ar = enabled.first(where: isArabicPC) ?? enabled.first(where: isArabic)
            ?? installed.first(where: isArabicPC) ?? installed.first(where: isArabic)

        return (en, ar)
    }

    static func allSourceIDs(includeAllInstalled: Bool) -> [String] {
        let list = TISCreateInputSourceList(nil, includeAllInstalled).takeRetainedValue() as! [TISInputSource]
        return list.compactMap { src in
            guard let p = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { return nil }
            return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
        }.filter { $0.contains("keylayout") }
    }

    private static func layoutData(id: String) -> Data? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource],
              let src = list.first,
              let p = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        return Unmanaged<CFData>.fromOpaque(p).takeUnretainedValue() as Data
    }

    private static func char(_ keyCode: Int, _ shift: Bool, _ layout: Data) -> String? {
        var dead: UInt32 = 0
        var length = 0
        var buf = [UniChar](repeating: 0, count: 4)
        let mods: UInt32 = shift ? UInt32(shiftKey >> 8) & 0xFF : 0
        let status = layout.withUnsafeBytes { raw -> OSStatus in
            let ptr = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress!
            return UCKeyTranslate(ptr, UInt16(keyCode), UInt16(kUCKeyActionDown), mods,
                                  UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                  &dead, buf.count, &length, &buf)
        }
        guard status == noErr, length > 0 else { return nil }
        let s = String(utf16CodeUnits: buf, count: length)
        return s.unicodeScalars.allSatisfy { $0.value >= 32 } ? s : nil
    }
}
