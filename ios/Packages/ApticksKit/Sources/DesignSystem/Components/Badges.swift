import Domain
import SwiftUI

public struct BotTag: View {
    public init() {}

    public var body: some View {
        Text("BOT")
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Theme.lime)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.limeTint))
    }
}

public struct TierBadge: View {
    let rating: Int
    var showRating: Bool

    public init(rating: Int, showRating: Bool = false) {
        self.rating = rating
        self.showRating = showRating
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "shield").font(.system(size: 12, weight: .bold))
            Text(tierFor(rating).name + (showRating ? " · \(grouped(rating))" : ""))
        }
        .font(.ui(13, .semibold))
        .foregroundStyle(Theme.violet)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.violetTint))
    }
}

// A small rounded label: result chips, topic tags.
public struct Chip: View {
    let text: String
    var fg: Color
    var bg: Color
    var size: CGFloat

    public init(_ text: String, fg: Color = Theme.soft, bg: Color = Theme.raised, size: CGFloat = 12) {
        self.text = text
        self.fg = fg
        self.bg = bg
        self.size = size
    }

    public var body: some View {
        Text(text)
            .font(.ui(size, .bold))
            .foregroundStyle(fg)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(bg))
    }
}

// A rating change: lime when up, red when down.
public struct Delta: View {
    let value: Int?

    public init(_ value: Int?) { self.value = value }

    public var body: some View {
        if let value {
            Text(signed(value)).font(.mono(14)).foregroundStyle(value >= 0 ? Theme.lime : Theme.redSoft)
        } else {
            Text("—").font(.mono(14, .regular)).foregroundStyle(Theme.faint)
        }
    }
}
