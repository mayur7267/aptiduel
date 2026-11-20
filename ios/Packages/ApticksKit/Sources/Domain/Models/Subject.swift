import Foundation

// What a Quick Match is about (supabase/migrations/0022_subjects.sql,
// 0024_english.sql). Every duel before Coding is Aptitude.
public enum Subject: String, Codable, Sendable, Hashable, CaseIterable {
    case aptitude, coding, english

    // A subject this version doesn't know yet reads as Aptitude, so a newer
    // server never breaks an older app.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Subject(rawValue: raw) ?? .aptitude
    }
}

extension Subject {
    // The subject a new friend duel starts in: the tab open on Home's
    // Quick Match card (same key as the website), if it can be played.
    public static func openOnHome(_ defaults: UserDefaults = .standard) -> Subject {
        defaults.string(forKey: "apticks-subject").flatMap { SubjectTab(rawValue: $0)?.subject } ?? .aptitude
    }

    public var label: String {
        switch self {
        case .aptitude: "Aptitude"
        case .coding: "Coding"
        case .english: "English"
        }
    }

    // "Coding Quick Match", or just "Quick Match" for Aptitude.
    public var quickMatchName: String { self == .aptitude ? "Quick Match" : "\(label) Quick Match" }

    public var ratingLabel: String { self == .aptitude ? "Rating" : "\(label) rating" }

    // "an aptitude duel", "a coding duel", "an English duel".
    public var duelPhrase: String {
        switch self {
        case .aptitude: "an aptitude duel"
        case .coding: "a coding duel"
        case .english: "an English duel"
        }
    }
}

// The four binder tabs on Home, like the website's. GK is shown as
// coming soon.
public enum SubjectTab: String, Sendable, Hashable, CaseIterable, Identifiable {
    case aptitude, coding, english, gk

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .aptitude: "Aptitude"
        case .coding: "Coding"
        case .english: "English"
        case .gk: "GK"
        }
    }

    public var glyph: String {
        switch self {
        case .aptitude: "Σ"
        case .coding: "</>"
        case .english: "Aa"
        case .gk: "?"
        }
    }

    // The subject you can play, or nil while it's coming soon.
    public var subject: Subject? {
        switch self {
        case .aptitude: .aptitude
        case .coding: .coding
        case .english: .english
        case .gk: nil
        }
    }

    public var soon: Bool { subject == nil }
}

// Each coding question is one program, printed in every language below,
// so two players reading different languages can share a duel.
public enum CodeLang: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case c, cpp, java, python, pseudo

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .c: "C"
        case .cpp: "C++"
        case .java: "Java"
        case .python: "Python"
        case .pseudo: "Pseudo"
        }
    }

    // The editor tab's file name.
    public var file: String {
        switch self {
        case .c: "main.c"
        case .cpp: "main.cpp"
        case .java: "Main.java"
        case .python: "main.py"
        case .pseudo: "pseudocode"
        }
    }
}

// A coding question's program in each language.
public struct CodeSet: Codable, Sendable, Hashable {
    public let c: String
    public let cpp: String
    public let java: String
    public let python: String
    public let pseudo: String

    public init(c: String, cpp: String, java: String, python: String, pseudo: String) {
        self.c = c
        self.cpp = cpp
        self.java = java
        self.python = python
        self.pseudo = pseudo
    }

    public func text(_ lang: CodeLang) -> String {
        switch lang {
        case .c: c
        case .cpp: cpp
        case .java: java
        case .python: python
        case .pseudo: pseudo
        }
    }
}

// Your rating and games in each subject (my_subjects). Aptitude's is the
// rating on your profile.
public struct SubjectRating: Decodable, Sendable, Hashable {
    public let rating: Int
    public let games: Int
}

public struct SubjectRatings: Decodable, Sendable, Hashable {
    public let aptitude: SubjectRating
    public let coding: SubjectRating
    public let english: SubjectRating? // nil before 0024_english.sql

    // One rating across subjects, for show (the player card, a profile's
    // tier): each subject's rating weighted by the games played in it, so
    // a subject never played doesn't count. Matchmaking and Ranks stay per
    // subject. Port of overallRating in web/src/lib/format.ts.
    public static func overall(_ ratings: SubjectRatings?, aptitude: Int) -> Int {
        let played = [ratings?.aptitude, ratings?.coding, ratings?.english].compactMap { $0 }.filter { $0.games > 0 }
        let games = played.reduce(0) { $0 + $1.games }
        guard games > 0 else { return aptitude }
        let sum = played.reduce(0.0) { $0 + Double($1.rating * $1.games) }
        return Int((sum / Double(games)).rounded())
    }

    public subscript(_ s: Subject) -> SubjectRating? {
        switch s {
        case .aptitude: aptitude
        case .coding: coding
        case .english: english
        }
    }
}
