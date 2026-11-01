import Foundation

// Starting a match can hand back an unfinished one instead.
public struct MatchStart: Decodable, Sendable, Hashable {
    public let duelId: String
    public let resumed: Bool?
}

public struct DuelRef: Decodable, Sendable, Hashable {
    public let duelId: String
}

public struct NewChallenge: Decodable, Sendable, Hashable {
    public let duelId: String
    public let code: String
}

public struct ShareCode: Decodable, Sendable, Hashable {
    public let code: String
}

// How the database's JSON is read: snake_case keys.
public enum Wire {
    public static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }
}

// Postgres timestamps, with or without fractional seconds.
public func parseTimestamp(_ s: String) -> Date? {
    let withFraction = ISO8601DateFormatter()
    withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = withFraction.date(from: s) { return d }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    if let d = plain.date(from: s) { return d }
    // More than millisecond precision: trim the fraction to three digits.
    if let dot = s.firstIndex(of: "."), let end = s[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
        let digits = s[s.index(after: dot)..<end].prefix(3)
        return withFraction.date(from: s[..<dot] + "." + digits + s[end...])
    }
    return nil
}
