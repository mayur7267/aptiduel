import Foundation
import SwiftUI

// Company practice: duels built only from topics on that company's
// aptitude test. Names match the company_tags set by supabase/seed.sql.
// comingSoon = true means questions aren't tagged yet; shown but disabled.
public struct Company: Hashable, Sendable, Identifiable {
    public let slug: String
    public let name: String
    public let blurb: String
    public let emoji: String
    public let hex: String          // brand colour, e.g. "#1565c0"
    public let comingSoon: Bool
    public var id: String { slug }

    public init(slug: String, name: String, blurb: String,
                emoji: String = "🔵", hex: String = "#4a4a4a",
                comingSoon: Bool = false) {
        self.slug = slug; self.name = name; self.blurb = blurb
        self.emoji = emoji; self.hex = hex; self.comingSoon = comingSoon
    }
}

public let COMPANIES: [Company] = [
    Company(slug: "tcs-nqt",       name: "TCS NQT",       blurb: "Numerical, reasoning and verbal",   emoji: "🔵", hex: "#1565c0"),
    Company(slug: "infosys",       name: "Infosys",        blurb: "Puzzles, reasoning and maths",      emoji: "🟣", hex: "#4527a0"),
    Company(slug: "accenture",     name: "Accenture",      blurb: "Abstract and critical reasoning",   emoji: "🟣", hex: "#6a0dad"),
    Company(slug: "wipro",         name: "Wipro",          blurb: "Quant, analytical and verbal",      emoji: "🟢", hex: "#1b5e20"),
    Company(slug: "cognizant",     name: "Cognizant",      blurb: "Quant, logical and English",        emoji: "🔵", hex: "#0277bd"),
    Company(slug: "capgemini",     name: "Capgemini",      blurb: "Logic games, English and maths",    emoji: "🔵", hex: "#01579b"),
    Company(slug: "hcl",           name: "HCL Tech",       blurb: "Analytical, reasoning and verbal",  emoji: "🟢", hex: "#2e7d32"),
    Company(slug: "tech-mahindra", name: "Tech Mahindra",  blurb: "Quant, reasoning and verbal",       emoji: "🔴", hex: "#b71c1c"),
    Company(slug: "hexaware",      name: "Hexaware",       blurb: "Numerical, verbal and reasoning",   emoji: "🟠", hex: "#e65100"),
    Company(slug: "mphasis",       name: "Mphasis",        blurb: "Quant, logical and verbal",         emoji: "🟣", hex: "#4a148c"),
    Company(slug: "deloitte",      name: "Deloitte",       blurb: "Numerical, logical and verbal",     emoji: "🟢", hex: "#006064"),
]

public func company(named name: String?) -> Company? {
    COMPANIES.first { $0.name == name }
}
