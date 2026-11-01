import SwiftUI

// The website's palette (web/src/app/globals.css).
public enum Theme {
    public static let ink = Color(hex: "0b0e17")
    public static let bar = Color(hex: "0f131d")
    public static let surface = Color(hex: "151a26")
    public static let raised = Color(hex: "1d2333")
    public static let line = Color(hex: "272e40")
    public static let lineStrong = Color(hex: "3a4256")
    public static let field = Color(hex: "2d3548")
    public static let text = Color(hex: "f2f4f8")
    public static let soft = Color(hex: "d3d8e3")
    public static let muted = Color(hex: "a6aec0")
    public static let faint = Color(hex: "8089a0")

    public static let lime = Color(hex: "c8f135")
    public static let limeInk = Color(hex: "2a3410")
    public static let limeTint = Color(hex: "222a10")
    public static let limeEdge = Color(hex: "9fc41f")
    public static let limePop = Color(hex: "5f7710")
    public static let orange = Color(hex: "ff8a4c")
    public static let orangeSoft = Color(hex: "ffb088")
    public static let orangeTint = Color(hex: "2a1c12")
    public static let violet = Color(hex: "a594ff")
    public static let violetSoft = Color(hex: "dcd5ff")
    public static let violetTint = Color(hex: "241f45")
    public static let violetStrong = Color(hex: "3a3270")
    public static let violetDeep = Color(hex: "251f4a")
    public static let red = Color(hex: "ff6b7a")
    public static let redSoft = Color(hex: "ff8f9b")
    public static let redTint = Color(hex: "3a1e28")
    public static let cyan = Color(hex: "5ce1e6")

    public static let pop = Color(hex: "2b3247") // default sticker shadow
    public static let meRow = Color(hex: "161d10")
}

extension Color {
    public init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        if hex.count == 3 {
            let r = (v >> 8) & 0xF, g = (v >> 4) & 0xF, b = v & 0xF
            self.init(.sRGB, red: Double(r * 17) / 255, green: Double(g * 17) / 255, blue: Double(b * 17) / 255)
        } else {
            self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
        }
    }
}
