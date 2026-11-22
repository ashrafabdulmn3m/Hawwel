import SwiftUI
import Combine

struct ActivityTab: View {
    @EnvironmentObject var stats: Stats
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: HW.gap) {
            // 4 جنب بعض، ولو النافذة ضيقة يبقوا 2×2
            ViewThatFits(in: .horizontal) {
                HStack(spacing: HW.gap) { statCards }
                Grid(horizontalSpacing: HW.gap, verticalSpacing: HW.gap) {
                    GridRow {
                        statCard(Num.grouped(stats.data.total), L("act.total"))
                        statCard(Num.grouped(stats.weekCount), L("act.week"))
                    }
                    GridRow {
                        statCard(Num.compact(stats.data.chars), L("act.chars"))
                        statCard(TimeSaved.text(chars: stats.data.chars), L("act.time"))
                    }
                }
            }

            chartCard

            HStack(alignment: .top, spacing: HW.gap) {
                directionCard
                appsCard
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(L("act.foot")).font(HW.font(11.5)).foregroundStyle(HW.muted)
                Spacer(minLength: 8)
                Button(L("act.clear")) { confirmClear = true }
                    .buttonStyle(HWButtonStyle(kind: .danger))
                    .disabled(stats.data.total == 0)
            }
        }
        .confirmationDialog(L("act.clear.confirm"), isPresented: $confirmClear) {
            Button(L("act.clear"), role: .destructive) { stats.clear() }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("act.clear.confirmDesc"))
        }
    }

    @ViewBuilder private var statCards: some View {
        statCard(Num.grouped(stats.data.total), L("act.total"))
        statCard(Num.grouped(stats.weekCount), L("act.week"))
        statCard(Num.compact(stats.data.chars), L("act.chars"))
        statCard(TimeSaved.text(chars: stats.data.chars), L("act.time"))
    }

    private func statCard(_ value: String, _ label: String) -> some View {
        StatView(value: value, label: label).hwCard()
    }

    // MARK: - آخر 7 أيام

    private var chartCard: some View {
        let days = stats.last7
        let peak = max(days.map(\.count).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 8) {
            CardTitle(text: L("act.last7"))
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    let isToday = index == days.count - 1
                    VStack(spacing: 6) {
                        Spacer(minLength: 0)
                        Text("\(day.count)")
                            .font(HW.number(10.5, .regular))
                            .foregroundStyle(HW.muted)
                        UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 3,
                                               bottomTrailingRadius: 3, topTrailingRadius: 6, style: .continuous)
                            .fill(isToday ? HW.accent : HW.accent.opacity(0.35))
                            .frame(maxWidth: 34)
                            .frame(height: max(3, CGFloat(day.count) / CGFloat(peak) * 62))
                        Text(Self.dayName(day.date))
                            .font(HW.font(10.5, isToday ? .semi : .regular))
                            .foregroundStyle(isToday ? HW.ink : HW.muted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110)
        }
        .hwCard()
    }

    /// اسم اليوم المختصر (سبت، حد… / Sat, Sun…)
    static func dayName(_ date: Date) -> String {
        L("day.\(Calendar.current.component(.weekday, from: date))")
    }

    // MARK: - اتجاه التحويل

    private var directionCard: some View {
        let share = stats.toArabicShare
        let toArabic = Int(((share ?? 0) * 100).rounded())
        return VStack(alignment: .leading, spacing: 8) {
            CardTitle(text: L("act.dir"))
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(HW.accent).frame(width: geo.size.width * (share ?? 0))
                    Rectangle().fill(share == nil ? HW.field : HW.accent.opacity(0.35))
                }
            }
            .frame(height: 8)
            .background(HW.field)
            .clipShape(Capsule())
            VStack(spacing: 4) {
                directionLabel(L("act.dir.toArabic"), share == nil ? "–" : "\(toArabic)%", color: HW.accent)
                directionLabel(L("act.dir.toEnglish"), share == nil ? "–" : "\(100 - toArabic)%", color: HW.accent.opacity(0.35))
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .hwCard()
    }

    private func directionLabel(_ title: String, _ value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).lineLimit(1)
            Spacer(minLength: 8)
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .font(HW.font(12))
    }

    // MARK: - أكتر برامج

    private var appsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardTitle(text: L("act.apps"))
            let apps = stats.topApps
            if apps.isEmpty {
                Text(L("act.apps.empty")).font(HW.font(11.5)).foregroundStyle(HW.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(apps, id: \.name) { app in
                    HStack(spacing: 10) {
                        Text(app.name).font(HW.font(12)).lineLimit(1).truncationMode(.tail)
                            .frame(width: 80, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(HW.field)
                                Capsule().fill(HW.accent).frame(width: geo.size.width * app.share)
                            }
                        }
                        .frame(height: 6)
                        Text("\(Int((app.share * 100).rounded()))%")
                            .font(HW.number(12, .regular))
                            .foregroundStyle(HW.muted)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .hwCard()
    }
}
