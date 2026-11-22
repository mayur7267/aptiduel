import DesignSystem
import Domain
import SwiftUI

// One day of the Streak Tower: a chunky block in the day's colour, with
// the day number and the weekday (web/src/components/streak-block.tsx).
public struct StreakBlockView: View {
    let day: Int
    let weekday: String
    let width: CGFloat
    let height: CGFloat

    public init(day: Int, weekday: String, width: CGFloat, height: CGFloat) {
        self.day = day
        self.weekday = weekday
        self.width = width
        self.height = height
    }

    static let fills = [Theme.lime, Theme.violet, Theme.orange, Color(hex: "7fd3ff")]
    public static func fill(_ day: Int) -> Color { fills[Streak.colorIndex(day: day)] }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let fs = height * 0.34
        ZStack {
            shape.fill(Theme.ink).offset(y: height * 0.12)
            shape.fill(Self.fill(day))
            // Bricks: two seams, offset like a wall.
            Canvas { g, size in
                var p = Path()
                p.move(to: CGPoint(x: 0, y: size.height / 2))
                p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                p.move(to: CGPoint(x: size.width * 0.38, y: 0))
                p.addLine(to: CGPoint(x: size.width * 0.38, y: size.height / 2))
                p.move(to: CGPoint(x: size.width * 0.68, y: size.height / 2))
                p.addLine(to: CGPoint(x: size.width * 0.68, y: size.height))
                g.stroke(p, with: .color(Theme.ink.opacity(0.15)), lineWidth: 3)
            }
            .clipShape(shape)
            HStack {
                Text("DAY \(day)").font(.display(fs)).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text(weekday).font(.mono(fs * 0.8)).opacity(0.7)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, width * 0.08)
            shape.strokeBorder(Theme.ink, lineWidth: 3.5)
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day \(day)")
    }
}
