import Foundation

// The placement test you're preparing for (my_drive), with your practice
// on that company's topics in the last 30 days. Everything but company is
// missing when no test is set.
public struct Drive: Decodable, Sendable, Hashable {
    public let company: String?
    public let driveOn: String? // yyyy-MM-dd
    public let daysLeft: Int? // negative once it's past
    public let answered: Bool? // told us how it went
    public let cleared: String? // "yes", "no" or "skipped"
    public let practised: Int?
    public let accuracy: Int? // percent right
    public let weakTopics: [String]?

    public enum Stage: Hashable, Sendable {
        case unset
        case upcoming(days: Int)
        case today
        case howDidItGo
        case answered
    }

    public var stage: Stage {
        guard company != nil, let daysLeft else { return .unset }
        if answered == true { return .answered }
        if daysLeft < 0 { return .howDidItGo }
        return daysLeft == 0 ? .today : .upcoming(days: daysLeft)
    }

    // "Sun, 15 Nov"
    public var prettyDate: String? {
        guard let driveOn, let date = Self.day.date(from: driveOn) else { return nil }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "en_IN")))
    }

    // The calendar day a date falls on, as the database writes it.
    public static func dayString(_ date: Date) -> String { day.string(from: date) }

    private static var day: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
}
