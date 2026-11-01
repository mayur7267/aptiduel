import DesignSystem
import Domain
import SwiftUI

// Tier theme helper for colours and gradients
private struct TierTheme {
    let color: Color
    let gradient: [Color]
    let name: String

    static func forTier(_ name: String) -> TierTheme {
        switch name {
        case "Fresher":
            return TierTheme(color: Theme.muted, gradient: [Theme.faint, Theme.soft], name: name)
        case "Trainee":
            return TierTheme(color: Theme.cyan, gradient: [Theme.cyan, Theme.violet], name: name)
        case "Analyst":
            return TierTheme(color: Theme.lime, gradient: [Theme.lime, Theme.cyan], name: name)
        case "Consultant":
            return TierTheme(color: Theme.violet, gradient: [Theme.violet, Theme.orange], name: name)
        case "Lead":
            return TierTheme(color: Theme.orange, gradient: [Theme.orange, Color(hex: "ffd700")], name: name)
        case "Architect":
            return TierTheme(color: Color(hex: "ffd700"), gradient: [Color(hex: "ffd700"), Theme.lime], name: name)
        default:
            return TierTheme(color: Theme.lime, gradient: [Theme.lime, Theme.cyan], name: name)
        }
    }
}

// Gaming-style XP Progress Card: Tier badge with glow, thick animated XP bar,
// 4 arcade stat capsules, and rating history on graph paper.
struct ProgressGraph: View {
    let me: Me?
    let history: [Int]
    let rating: Int
    let weekChange: Int
    let winRate: Int?
    @State private var drawn = 0.0
    @State private var circled = 0.0
    @State private var xpBarAnimated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(me: Me? = nil, history: [Int], rating: Int, weekChange: Int, winRate: Int? = nil) {
        self.me = me
        self.history = history
        self.rating = rating
        self.weekChange = weekChange
        self.winRate = winRate
    }

    private var hasHistory: Bool { history.count >= 2 }

    var body: some View {
        let tier = tierFor(rating)
        let theme = TierTheme.forTier(tier.name)
        let xpPercent = Int((tier.progress * 100).rounded())

        VStack(alignment: .leading, spacing: 14) {
            // Header: XP Tier Emblem + Rating
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("XP TIER")
                            .font(.mono(10, .bold))
                            .tracking(2.0)
                            .foregroundStyle(Theme.muted)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(theme.color)
                                .frame(width: 6, height: 6)
                            Text(tier.name.uppercased())
                                .font(.mono(10, .bold))
                                .tracking(1.2)
                                .foregroundStyle(theme.color)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(theme.color.opacity(0.14))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.color.opacity(0.4), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(grouped(rating))
                            .font(.mono(24, .bold))
                            .foregroundStyle(Theme.text)
                        Text("XP")
                            .font(.mono(12, .semibold))
                            .foregroundStyle(Theme.muted)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if weekChange != 0 {
                        Text("\(signed(weekChange)) this week")
                            .font(.mono(11, .bold))
                            .foregroundStyle(weekChange > 0 ? Theme.lime : Theme.redSoft)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(weekChange > 0 ? Theme.limeTint : Theme.redTint)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder((weekChange > 0 ? Theme.lime : Theme.redSoft).opacity(0.3), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if let rank = me?.collegeRank {
                        Text("#\(rank) in college")
                            .font(.mono(10, .semibold))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }

            // XP Gauge Progress Bar
            VStack(spacing: 6) {
                HStack {
                    Text("LEVEL PROGRESS")
                        .font(.mono(10, .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    if let next = tier.next {
                        Text("\(xpPercent)% (\(next.min - rating) to \(next.name))")
                            .font(.mono(11, .semibold))
                            .foregroundStyle(Theme.soft)
                    } else {
                        Text("MAX TIER REACHED 🏆")
                            .font(.mono(11, .bold))
                            .foregroundStyle(Theme.lime)
                    }
                }

                // Inset track with animated fill
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.ink)
                            .overlay(Capsule().strokeBorder(Theme.lineStrong, lineWidth: 1))

                        let fillWidth = max(8, geo.size.width * CGFloat(xpBarAnimated ? tier.progress : 0))
                        LinearGradient(colors: theme.gradient, startPoint: .leading, endPoint: .trailing)
                            .clipShape(Capsule())
                            .frame(width: fillWidth)
                    }
                }
                .frame(height: 12)

                HStack {
                    Text("\(tier.name) · \(grouped(tier.min))")
                        .font(.mono(9))
                        .foregroundStyle(Theme.faint)
                    Spacer()
                    if let next = tier.next {
                        Text("\(next.name) · \(grouped(next.min))")
                            .font(.mono(9))
                            .foregroundStyle(Theme.faint)
                    } else {
                        Text("Top Tier")
                            .font(.mono(9))
                            .foregroundStyle(Theme.faint)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.ink.opacity(0.45)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line.opacity(0.7), lineWidth: 1))

            // 4 Arcade Stat Badges
            if let me {
                HStack(spacing: 8) {
                    statCapsule(emoji: "⚔️", value: "\(me.gamesPlayed)", label: "DUELS", accent: Theme.text)
                    statCapsule(emoji: "🏆", value: "\(me.wins)", label: "WINS", accent: Theme.lime)
                    statCapsule(emoji: "🎯", value: winRate.map { "\($0)%" } ?? "—", label: "WIN %", accent: Theme.text)
                    statCapsule(emoji: "🔥", value: "\(me.streak)d", label: "STREAK", accent: Theme.orange)
                }
            }

            // Rating History Graph
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("RATING HISTORY")
                        .font(.mono(10, .bold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    // One point per rated duel, plus where you started.
                    Text(hasHistory ? "last \(history.count - 1) \(history.count == 2 ? "duel" : "duels")" : "no duels yet")
                        .font(.mono(9))
                        .foregroundStyle(Theme.faint)
                }

                GeometryReader { g in
                    let plot = layout(size: g.size, next: tier.next)
                    ZStack(alignment: .topLeading) {
                        Canvas { ctx, size in
                            graphPaper(ctx, size)
                            for line in plot.tiers {
                                var p = Path()
                                p.move(to: CGPoint(x: 0, y: line.y))
                                p.addLine(to: CGPoint(x: size.width, y: line.y))
                                ctx.stroke(p, with: .color(line.next ? Theme.lime.opacity(0.7) : Theme.lineStrong),
                                           style: StrokeStyle(lineWidth: line.next ? 1.5 : 1, dash: [5, 4]))
                                ctx.draw(Text(line.label).font(.mono(9, .bold)).foregroundColor(line.next ? Theme.lime : Theme.faint),
                                         at: CGPoint(x: size.width - 2, y: line.y - 7), anchor: .trailing)
                            }
                        }
                        pencil(plot.points).trim(from: 0, to: drawn)
                            .stroke(Theme.text, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                        ForEach(Array(plot.points.enumerated()), id: \.offset) { i, p in
                            Circle().fill(Theme.text).frame(width: 5, height: 5)
                                .position(p)
                                .opacity(drawn >= Double(i) / Double(max(1, plot.points.count - 1)) ? 1 : 0)
                        }
                        if let last = plot.points.last {
                            redCircle(around: last).trim(from: 0, to: circled)
                                .stroke(Theme.redSoft, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                            RedPen(text: hasHistory ? "\(signed(weekChange)) this week!" : "your first duel goes here", size: 14)
                                .fixedSize()
                                .position(x: max(70, last.x - 62), y: max(14, last.y - 30))
                                .opacity(circled)
                        }
                    }
                }
                .frame(height: 140)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line.opacity(0.8), lineWidth: 1))
            }
        }
        .padding(16)
        .card(20)
        .onAppear {
            if reduceMotion {
                drawn = 1
                circled = 1
                xpBarAnimated = true
            } else {
                withAnimation(.easeOut(duration: 0.9).delay(0.1)) { xpBarAnimated = true }
                withAnimation(.easeInOut(duration: 1.3).delay(0.3)) { drawn = 1 }
                withAnimation(.easeOut(duration: 0.5).delay(1.6)) { circled = 1 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating \(rating). \(hasHistory ? "\(signed(weekChange)) this week." : "")")
    }

    private func statCapsule(emoji: String, value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 2) {
            Text(emoji).font(.system(size: 13))
            Text(value).font(.mono(14, .bold)).foregroundStyle(accent)
            Text(label).font(.mono(8, .bold)).tracking(1.0).foregroundStyle(Theme.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line.opacity(0.7), lineWidth: 1))
    }

    private struct Plot {
        var points: [CGPoint]
        var tiers: [(y: CGFloat, label: String, next: Bool)]
    }

    private func layout(size: CGSize, next: Tier?) -> Plot {
        let series = hasHistory ? history : [rating, rating]
        var lo = Double(series.min() ?? rating) - 40
        var hi = Double(max(series.max() ?? rating, next?.min ?? rating)) + 30
        if hi - lo < 120 { hi = lo + 120 }
        if !hasHistory { lo = Double(rating) - 80 }
        let top: CGFloat = 12, bottom: CGFloat = 10, right: CGFloat = 26
        func y(_ v: Double) -> CGFloat { top + (size.height - top - bottom) * CGFloat(1 - (v - lo) / (hi - lo)) }
        let count = series.count
        let points = series.enumerated().map { i, v in
            // A hand-drawn wobble, the same every time.
            let wobble = CGFloat(((i * 37) % 7) - 3) * 0.6
            return CGPoint(x: 8 + (size.width - right - 8) * CGFloat(i) / CGFloat(max(1, count - 1)), y: y(Double(v)) + wobble)
        }
        let tiers = TIERS.filter { Double($0.min) > lo && Double($0.min) < hi }.map { t in
            (y: y(Double(t.min)), label: "\(t.name.uppercased()) \(grouped(t.min))", next: t.name == next?.name)
        }
        return Plot(points: hasHistory ? points : [points[0]], tiers: tiers)
    }

    private func graphPaper(_ ctx: GraphicsContext, _ size: CGSize) {
        var fine = Path()
        var x: CGFloat = 0
        while x <= size.width { fine.addRect(CGRect(x: x, y: 0, width: 0.5, height: size.height)); x += 14 }
        var y: CGFloat = 0
        while y <= size.height { fine.addRect(CGRect(x: 0, y: y, width: size.width, height: 0.5)); y += 14 }
        ctx.fill(fine, with: .color(Theme.lime.opacity(0.07)))
    }

    private func pencil(_ pts: [CGPoint]) -> Path {
        Path { p in
            guard let first = pts.first else { return }
            p.move(to: first)
            for pt in pts.dropFirst() { p.addLine(to: pt) }
        }
    }

    // A quick, slightly-too-big loop of red pen, as a teacher would draw it.
    private func redCircle(around c: CGPoint) -> Path {
        Path { p in
            let steps = 40
            for i in 0...steps {
                let t = Double(i) / Double(steps) * 2.15 * .pi - 0.6
                let r = 15 + 2.5 * sin(t * 1.7)
                let pt = CGPoint(x: c.x + CGFloat(cos(t) * r * 1.25), y: c.y + CGFloat(sin(t) * r))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
    }
}

// Your stats as a mark sheet, the week as OMR bubbles, and Tiko's remark.
struct ReportCard: View {
    let me: Me
    let winRate: Int?

    private var remark: String {
        if me.gamesPlayed == 0 { return "Yet to appear. All the best!" }
        if let winRate, winRate >= 60 { return "Outstanding! Keep it up." }
        if me.streak >= 3 { return "Great streak. Don't break it!" }
        if let winRate, winRate >= 40 { return "Good work. Practise daily." }
        return "Needs practice. You've got this!"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("REPORT CARD").font(.mono(12)).tracking(2.4).foregroundStyle(Theme.muted)
                Spacer()
                Text("SEASON 1").font(.mono(10, .semibold)).tracking(1.4).foregroundStyle(Theme.faint)
            }
            VStack(spacing: 9) {
                row("Duels played", "\(me.gamesPlayed)")
                row("Wins", "\(me.wins)")
                row("Win rate", winRate.map { "\($0)%" } ?? "—")
                row("Best streak", "\(me.streakBest) \(me.streakBest == 1 ? "day" : "days")")
            }
            Rectangle().fill(Theme.line).frame(height: 1)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ATTENDANCE").font(.mono(10, .bold)).tracking(1.6).foregroundStyle(Theme.faint)
                    Spacer()
                    Label("\(me.streak)-day streak", systemImage: "flame.fill").font(.ui(12, .bold)).foregroundStyle(Theme.orange)
                }
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        let done = i < me.dailyWeek.count && me.dailyWeek[i]
                        VStack(spacing: 4) {
                            ZStack {
                                Circle().strokeBorder(i == me.todayIdx ? Theme.lime : Theme.lineStrong, lineWidth: 1.5)
                                if done { Circle().fill(Theme.text).padding(4) }
                            }
                            .frame(width: 26, height: 26)
                            Text(["M", "T", "W", "T", "F", "S", "S"][i]).font(.mono(10, .bold)).foregroundStyle(Theme.faint)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("REMARKS").font(.mono(10, .bold)).tracking(1.6).foregroundStyle(Theme.faint)
                    RedPen(text: remark, size: 17, tilt: -2).padding(.top, 2)
                }
                Spacer()
                RedPen(text: "— Tiko", size: 14, tilt: -6)
            }
        }
        .padding(16)
        .card(20)
        .accessibilityElement(children: .combine)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(label).font(.ui(14, .semibold)).foregroundStyle(Theme.soft)
            DottedLeader()
            Text(value).font(.mono(15)).foregroundStyle(Theme.text)
        }
    }
}

// The dots between a label and its value.
private struct DottedLeader: View {
    var body: some View {
        Line().stroke(Theme.lineStrong, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.1, 5]))
            .frame(height: 1.5)
            .offset(y: -4)
    }

    private struct Line: Shape {
        nonisolated func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: 0, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}
