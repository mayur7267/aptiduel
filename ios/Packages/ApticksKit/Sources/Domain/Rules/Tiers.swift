import Foundation

// Rating tiers, from Fresher to Architect (web/src/lib/format.ts).

public struct Tier: Sendable, Hashable {
    public let name: String
    public let min: Int
}

public let TIERS = [
    Tier(name: "Fresher", min: 0),
    Tier(name: "Trainee", min: 900),
    Tier(name: "Analyst", min: 1100),
    Tier(name: "Consultant", min: 1300),
    Tier(name: "Lead", min: 1500),
    Tier(name: "Architect", min: 1700),
]

public struct TierInfo: Sendable, Hashable {
    public let name: String
    public let min: Int
    public let next: Tier?
    public let progress: Double // towards the next tier, 0...1
    public let toNext: Int
}

public func tierFor(_ rating: Int) -> TierInfo {
    var i = TIERS.count - 1
    while i > 0 && rating < TIERS[i].min { i -= 1 }
    let tier = TIERS[i]
    let next = i + 1 < TIERS.count ? TIERS[i + 1] : nil
    let floor = i == 0 ? 800 : tier.min
    let progress = next.map { Swift.min(1, Swift.max(0, Double(rating - floor) / Double($0.min - floor))) } ?? 1
    return TierInfo(name: tier.name, min: tier.min, next: next, progress: progress, toNext: next.map { $0.min - rating } ?? 0)
}

// Whether a rating change crossed into a higher tier.
public func promoted(from before: Int, to after: Int) -> Bool {
    tierFor(after).min > tierFor(before).min
}
