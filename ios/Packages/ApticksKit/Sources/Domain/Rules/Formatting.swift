import Foundation

// 108000 -> "1:48"
public func clock(_ ms: Int) -> String {
    let total = max(0, Int((Double(ms) / 1000).rounded()))
    return "\(total / 60):" + String(format: "%02d", total % 60)
}

public func initials(_ name: String) -> String {
    let parts = name.split(whereSeparator: \.isWhitespace)
    guard let first = parts.first else { return "?" }
    if parts.count == 1 { return String(first.prefix(2)).uppercased() }
    return (String(first.prefix(1)) + String(parts.last!.prefix(1))).uppercased()
}

public func signed(_ n: Int) -> String {
    n > 0 ? "+\(n)" : n < 0 ? "−\(abs(n))" : "±0"
}

public func greeting(_ date: Date = Date(), calendar: Calendar = .current) -> String {
    let h = calendar.component(.hour, from: date)
    return h < 5 ? "Up late" : h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
}

// Time left until the daily challenge resets at midnight IST.
public func untilIstMidnight(_ now: Date) -> String {
    let ist = 5.5 * 3600.0
    let day = 86400.0
    let left = day - (now.timeIntervalSince1970 + ist).truncatingRemainder(dividingBy: day)
    let s = Int(left)
    let hh = s / 3600
    let mm = (s % 3600) / 60
    return hh > 0 ? "\(hh)h " + String(format: "%02d", mm) + "m" : "\(max(mm, 1))m"
}

public func batch(_ gradYear: Int?) -> String? {
    guard let gradYear else { return nil }
    return "Batch ’\(String(String(gradYear).suffix(2)))"
}

// 1500 -> "1,500", grouped the Indian way like the website.
public func grouped(_ n: Int) -> String {
    let f = NumberFormatter()
    f.locale = Locale(identifier: "en_IN")
    f.numberStyle = .decimal
    return f.string(from: NSNumber(value: n)) ?? String(n)
}

public let SECTION_LABEL = ["quant": "Quant", "reasoning": "Reasoning", "verbal": "Verbal"]

// "TCS NQT · Infosys · Wipro +4": a topic can be on many companies' tests.
public func companyList(_ companies: [String], shown: Int = 3) -> String {
    let more = companies.count - shown
    return companies.prefix(shown).joined(separator: " · ") + (more > 0 ? " +\(more)" : "")
}
