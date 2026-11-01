import SwiftUI

// Unbounded on the website; SF Pro Expanded is the closest system face.
// Scores, timers and ratings use the monospaced face, like JetBrains Mono there.
extension Font {
    public static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).width(.expanded)
    }

    public static func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // Big tile titles: SF Pro Compressed, heaviest weight.
    public static func poster(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.compressed)
    }

    // Handwriting, for the teacher's red-pen notes (Noteworthy ships with iOS).
    public static func hand(_ size: CGFloat) -> Font {
        .custom("Noteworthy-Bold", size: size)
    }

    public static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
