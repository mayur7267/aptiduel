import Domain
import SwiftUI

// Each name always gets the same colours, so lists are easy to scan.
private let AVATAR_TONES: [(Color, Color)] = [
    (Color(hex: "2b3350"), Color(hex: "dbe1f0")),
    (Color(hex: "3a2a3f"), Color(hex: "f3c4f0")),
    (Color(hex: "253a30"), Color(hex: "bff0cf")),
    (Color(hex: "3d2e1f"), Color(hex: "ffd2a8")),
    (Color(hex: "22344a"), Color(hex: "b9dcff")),
    (Color(hex: "3d2530"), Color(hex: "ffc2cc")),
    (Color(hex: "33361c"), Color(hex: "e6f5a6")),
]

// The same hash as the website, so a player has the same colour on both.
func avatarToneIndex(_ name: String) -> Int {
    var h: Int32 = 0
    for scalar in name.unicodeScalars {
        h = h &* 31 &+ Int32(String(scalar).utf16.first ?? 0)
    }
    return Int(abs(Int64(h)) % Int64(AVATAR_TONES.count))
}

public struct Avatar: View {
    let name: String
    var size: CGFloat

    public init(name: String, size: CGFloat = 44) {
        self.name = name
        self.size = size
    }

    public var body: some View {
        let tone = AVATAR_TONES[avatarToneIndex(name)]
        Text(initials(name))
            .font(.system(size: (size * 0.32).rounded(), weight: .bold))
            .foregroundStyle(tone.1)
            .frame(width: size, height: size)
            .background(Circle().fill(tone.0))
            .accessibilityHidden(true)
    }
}

// A player's avatar, or a robot for practice bots.
public struct PlayerAvatar: View {
    let name: String
    let bot: Bool
    var size: CGFloat

    public init(name: String, bot: Bool, size: CGFloat = 44) {
        self.name = name
        self.bot = bot
        self.size = size
    }

    public var body: some View {
        if bot {
            BotIcon(size: (size * 0.52).rounded(), color: Theme.lime)
                .frame(width: size, height: size)
                .background(Circle().fill(Theme.limeTint))
                .accessibilityHidden(true)
        } else {
            Avatar(name: name, size: size)
        }
    }
}

// The website's robot icon (no SF Symbol fits).
public struct BotIcon: View {
    var size: CGFloat
    var color: Color
    private static let svg = """
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 8V4H8"/><rect x="4" y="8" width="16" height="12" rx="2"/><path d="M2 14h2"/><path d="M20 14h2"/><path d="M15 13v2"/><path d="M9 13v2"/></svg>
    """

    public init(size: CGFloat = 20, color: Color = Theme.text) {
        self.size = size
        self.color = color
    }

    public var body: some View {
        SVGFigure(svg: Self.svg, color: color).frame(width: size, height: size)
    }
}
