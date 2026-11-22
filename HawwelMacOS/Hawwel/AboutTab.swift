import SwiftUI
import Combine

struct AboutTab: View {
    /// الجديد في الإصدار ده (النصوص في Localizable: about.log.1 … about.log.N)
    private static let changelogCount = 5

    var body: some View {
        VStack(spacing: HW.gap) {
            HStack(spacing: 16) {
                AppLogo(size: 72, radius: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hawwel · حوّل").font(HW.font(17, .bold))
                    Text(L("about.version", AppInfo.version))
                        .font(HW.font(11.5)).foregroundStyle(HW.muted)
                    Text(L("about.desc"))
                        .font(HW.font(12))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            .hwCard()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    CardTitle(text: L("about.newIn", AppInfo.version))
                    Spacer(minLength: 8)
                    Pill(text: L("badge.new"), kind: .info, showDot: false)
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(1...Self.changelogCount, id: \.self) { i in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•")
                            Text(L("about.log.\(i)")).fixedSize(horizontal: false, vertical: true)
                        }
                        .font(HW.font(12))
                        .foregroundStyle(HW.muted)
                    }
                }
            }
            .hwCard()

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                LinkTile(title: L("about.link.website"), url: Links.website)
                LinkTile(title: L("about.link.source"), url: Links.source)
                LinkTile(title: L("about.link.bug"), url: Links.reportBug)
                LinkTile(title: L("about.link.feature"), url: Links.feedback)
            }

            Text(L("about.share"))
                .font(HW.font(11.5))
                .foregroundStyle(HW.muted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }
}

private struct LinkTile: View {
    let title: String
    let url: URL
    @State private var hovering = false
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        Button { NSWorkspace.shared.open(url) } label: {
            HStack {
                Text(title).font(HW.font(12.5, .medium)).lineLimit(1)
                Spacer(minLength: 6)
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .scaleEffect(x: direction == .rightToLeft ? -1 : 1, y: 1)
            }
            .foregroundStyle(hovering ? HW.accent : HW.ink)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(HW.card, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(hovering ? HW.accent : HW.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(url.absoluteString)
    }
}
