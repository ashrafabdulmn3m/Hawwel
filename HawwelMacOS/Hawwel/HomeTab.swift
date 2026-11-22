import SwiftUI
import Combine
import AppKit

struct HomeTab: View {
    @Binding var tab: Tab
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var updater: UpdaterManager
    @EnvironmentObject var stats: Stats
    @EnvironmentObject var recorder: ShortcutRecorder

    var body: some View {
        VStack(spacing: HW.gap) {
            hero
            TryCard()
            HStack(alignment: .top, spacing: HW.gap) {
                permissionCard
                todayCard
            }
            .fixedSize(horizontal: false, vertical: true)
            if let version = updater.availableVersion {
                updateBanner(version)
            }
        }
    }

    // MARK: - حالة البرنامج والاختصار

    private var hero: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(engine.trusted ? L("home.hero.title") : L("home.hero.titleOff"))
                    .font(HW.font(15, .semi))
                Text(engine.trusted ? L("home.hero.desc") : L("home.hero.descOff"))
                    .font(HW.font(11.5))
                    .foregroundStyle(HW.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Keycaps(parts: recorder.parts, size: .large)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [HW.accentSoft, HW.card], startPoint: .topLeading, endPoint: UnitPoint(x: 0.7, y: 1)),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HW.line, lineWidth: 1))
    }

    // MARK: - الأذونات

    @ViewBuilder private var permissionCard: some View {
        if engine.trusted {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    CardTitle(text: L("home.perm.title"))
                    Spacer(minLength: 8)
                    Pill(text: L("home.perm.ok"), kind: .ok)
                }
                Text(L("home.perm.okDesc"))
                    .font(HW.font(11.5)).foregroundStyle(HW.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .hwCard()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    CardTitle(text: L("home.perm.title"))
                    Spacer(minLength: 8)
                    Pill(text: L("home.perm.off"), kind: .warn)
                }
                Text(L("home.perm.offDesc"))
                    .font(HW.font(11.5)).foregroundStyle(HW.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(L("home.perm.open")) {
                    engine.requestPermission()
                    engine.openAccessibilitySettings()
                }
                .buttonStyle(HWButtonStyle(kind: .primary))
                .padding(.top, 4)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .hwCard(fill: HW.warnSoft, border: HW.warn.opacity(0.35))
        }
    }

    // MARK: - ملخص النهارده

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                CardTitle(text: L("home.today"))
                Spacer(minLength: 8)
                Button(L("home.toActivity")) { tab = .activity }
                    .buttonStyle(HWButtonStyle(kind: .ghost))
                    .padding(.vertical, -4)
            }
            HStack(alignment: .top) {
                StatView(value: Num.grouped(stats.todayCount), label: L("home.today.conv"))
                Spacer(minLength: 8)
                StatView(value: Num.compact(stats.todayChars), label: L("home.today.chars"))
                Spacer(minLength: 8)
                StatView(value: TimeSaved.text(chars: stats.todayChars), label: L("home.today.saved"))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .hwCard()
    }

    // MARK: - بانر التحديث

    private func updateBanner(_ version: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(L("home.update.title", version)).font(HW.font(13, .semi))
                Text(L("home.update.desc")).font(HW.font(11.5)).foregroundStyle(HW.muted)
            }
            Spacer(minLength: 8)
            Button(L("home.update.now")) { updater.checkForUpdates() }
                .buttonStyle(HWButtonStyle(kind: .primary))
        }
        .hwCard(fill: HW.accentSoft, border: .clear)
    }
}

/// رقم كبير وتحته وصف
struct StatView: View {
    let value: String
    let label: String
    var size: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(HW.number(size))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(HW.font(11.5)).foregroundStyle(HW.muted).lineLimit(1)
                .fixedSize() // علشان ViewThatFits يعرف إن الكلمة مش هتتقص
        }
    }
}

/// الوقت اللي اتوفر: الحروف ÷ 200 حرف في الدقيقة
enum TimeSaved {
    static func text(chars: Int) -> String {
        let minutes = Stats.minutesSaved(chars: chars)
        if chars == 0 { return "0" }
        if minutes < 1 { return L("time.lessThanMin") }
        if minutes < 60 { return L("time.min", Int(minutes.rounded())) }
        let hours = minutes / 60
        return L("time.hour", hours < 10 ? String(format: "%.1f", hours) : "\(Int(hours.rounded()))")
    }
}

// MARK: - جرّب هنا

/// المستخدم بيجرّب الاختصار الحقيقي هنا: اكتب، حدد، اضغط الاختصار.
private struct TryCard: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var recorder: ShortcutRecorder
    @State private var text = L("try.sample")
    @State private var selection = NSRange(location: 0, length: 0)
    @State private var converted = false
    @State private var noSelection = false
    @State private var lit = false
    @State private var flash = false
    @State private var focused = false
    @State private var selectAllRequest = 0

    private var step: Int {
        if converted { return 3 }
        if selection.length > 0 { return 2 }
        return text.isEmpty ? 0 : 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CardTitle(text: L("try.title"))
                Spacer(minLength: 8)
                Button(L("try.reset")) {
                    text = L("try.sample")
                    converted = false
                    noSelection = false
                    selectAllRequest += 1
                }
                .buttonStyle(HWButtonStyle(kind: .ghost))
                .padding(.vertical, -4)
            }

            HStack(spacing: 6) {
                StepPill(number: 1, text: L("try.step1"), done: step >= 1)
                StepPill(number: 2, text: L("try.step2"), done: step >= 2)
                StepPill(number: 3, text: L("try.step3"), done: step >= 3)
            }

            ZStack(alignment: .topLeading) {
                TryTextView(text: $text, selection: $selection, focused: $focused, selectAllRequest: selectAllRequest)
                if text.isEmpty {
                    Text(L("try.placeholder"))
                        .font(HW.font(14))
                        .foregroundStyle(HW.muted.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 70)
            .background(HW.field, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(borderColor, lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(ringColor, lineWidth: 3).padding(-2))
            .animation(.easeOut(duration: 0.2), value: flash)
            .animation(.easeOut(duration: 0.2), value: focused)

            HStack {
                Keycaps(parts: recorder.parts, size: .small, lit: lit)
                Spacer(minLength: 8)
                statePill
            }
        }
        .hwCard()
        .onChange(of: text) { _, _ in converted = false }
        .onChange(of: selection) { _, new in
            if new.length > 0 { noSelection = false; converted = false }
        }
        .onReceive(engine.$lastEvent) { event in
            // بنهتم بس لو الاختصار اتداس وإحنا قدام (يعني في خانة التجربة)
            guard let event, NSApp.isActive, focused else { return }
            lit = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { lit = false }
            if event.success {
                converted = true
                noSelection = false
                flash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { flash = false }
            } else if engine.status == .noSelection {
                noSelection = true
            }
        }
    }

    private var borderColor: Color {
        if flash { return HW.ok }
        return focused ? HW.accent : HW.line
    }
    private var ringColor: Color {
        if flash { return HW.okSoft }
        return focused ? HW.accentSoft : .clear
    }

    @ViewBuilder private var statePill: some View {
        if converted {
            Pill(text: L("try.state.done") + " ✓", kind: .ok)
        } else if noSelection {
            Pill(text: L("try.state.noSel"), kind: .warn)
        } else if selection.length > 0 {
            Pill(text: L("try.state.sel"), kind: .info)
        } else {
            Pill(text: L("try.state.ready"), kind: .ok)
        }
    }
}

private struct StepPill: View {
    let number: Int
    let text: String
    let done: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("\(number)")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(done ? Color.white : HW.muted)
                .frame(width: 18, height: 18)
                .background(done ? HW.ok : HW.card, in: Circle())
                .overlay(Circle().stroke(done ? HW.ok : HW.line, lineWidth: 1))
            Text(text).font(HW.font(11.5)).lineLimit(1)
        }
        .foregroundStyle(done ? HW.ok : HW.muted)
        .padding(.leading, 3)
        .padding(.trailing, 10)
        .padding(.vertical, 2)
        .background(done ? HW.okSoft : HW.field, in: Capsule())
        .overlay(Capsule().stroke(done ? Color.clear : HW.line, lineWidth: 1))
        .animation(.easeOut(duration: 0.15), value: done)
    }
}

// MARK: - خانة الكتابة (NSTextView علشان نعرف التحديد)

private struct TryTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var focused: Bool
    var selectAllRequest: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let tv = FocusTextView()
        tv.onFocus = { context.coordinator.parent.focused = $0 }
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.font = .systemFont(ofSize: 14)
        tv.textColor = NSColor(name: nil) { a in
            NSColor(hw: a.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? 0xECEFF7 : 0x141B2D)
        }
        tv.insertionPointColor = tv.textColor ?? .labelColor
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.isAutomaticQuoteSubstitutionEnabled = false   // علشان ' و ; يفضلوا زي ما هم
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.baseWritingDirection = .natural
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.string = text

        scroll.documentView = tv
        context.coordinator.lastSelectAll = selectAllRequest
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = scroll.documentView as? NSTextView else { return }
        if tv.string != text { tv.string = text }
        if context.coordinator.lastSelectAll != selectAllRequest {
            context.coordinator.lastSelectAll = selectAllRequest
            tv.window?.makeFirstResponder(tv)
            tv.selectAll(nil)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TryTextView
        var lastSelectAll = 0
        init(_ parent: TryTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let range = tv.selectedRange()
            if range != parent.selection {
                DispatchQueue.main.async { self.parent.selection = range }
            }
        }
    }
}

private final class FocusTextView: NSTextView {
    var onFocus: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onFocus?(true) }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok { onFocus?(false) }
        return ok
    }
}
