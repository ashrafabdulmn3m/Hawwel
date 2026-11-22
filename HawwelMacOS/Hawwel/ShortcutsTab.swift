import SwiftUI
import Combine
import KeyboardShortcuts

typealias KeyboardShortcutsShortcut = KeyboardShortcuts.Shortcut

struct ShortcutsTab: View {
    @EnvironmentObject var recorder: ShortcutRecorder

    var body: some View {
        VStack(spacing: HW.gap) {
            if recorder.isRecording {
                recordingCard
                if case .conflict(let taken) = recorder.state {
                    conflictCard(taken)
                }
            } else {
                ListCard {
                    ListRow(title: L("sc.flip.title"), detail: L("sc.flip.desc")) {
                        HStack(spacing: 8) {
                            Keycaps(parts: recorder.parts)
                            Button(L("sc.change")) { recorder.start() }
                                .buttonStyle(HWButtonStyle())
                        }
                    }
                }
            }

            // الميزات الجاية (اختياري في التصميم)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("sc.soon.title")).font(HW.font(13, .medium))
                    Text(L("sc.soon.desc")).font(HW.font(11.5)).foregroundStyle(HW.muted)
                }
                Spacer(minLength: 8)
                Pill(text: L("sc.soon"), kind: .soon, showDot: false)
            }
            .hwCard()
            .opacity(0.6)

            HStack {
                Text(L("sc.foot")).font(HW.font(11.5)).foregroundStyle(HW.muted)
                Spacer(minLength: 8)
                Button(L("sc.resetDefault")) { recorder.resetToDefault() }
                    .buttonStyle(HWButtonStyle(kind: .ghost))
            }
        }
        .onDisappear { recorder.cancel() }
    }

    /// بيسجّل: بيوري الزراير اللي متضغطة دلوقتي
    private var recordingCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(L("sc.rec.title")).font(HW.font(13, .semi))
                Text(L("sc.rec.desc")).font(HW.font(11.5)).foregroundStyle(HW.muted)
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                let mods = ShortcutRecorder.symbols(recorder.liveModifiers)
                Keycaps(parts: mods + ["?"])
                    .opacity(mods.isEmpty ? 0.45 : 1)
                    .animation(.easeOut(duration: 0.1), value: mods)
            }
            Button(L("common.cancel")) { recorder.cancel() }
                .buttonStyle(HWButtonStyle(kind: .ghost))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HW.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HW.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }

    /// الاختصار اللي اتضغط مستخدم في الماك
    private func conflictCard(_ taken: KeyboardShortcutsShortcut) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Keycaps(parts: ShortcutRecorder.parts(of: taken), size: .small)
                Text(L("sc.conflict.desc")).font(HW.font(11.5)).foregroundStyle(HW.muted)
            }
            Spacer(minLength: 8)
            Pill(text: L("sc.conflict"), kind: .warn)
        }
        .hwCard()
    }
}
