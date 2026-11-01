import Foundation

public enum BoardScope: String, Decodable, Sendable, Hashable, CaseIterable {
    case college, india

    public var title: String { self == .college ? "My college" : "All India" }
}

public struct BoardRow: Decodable, Sendable, Hashable {
    public let id: String? // for opening their profile
    public let rank: Int
    public let name: String
    public let rating: Int
    public let college: String?
    public let gradYear: Int?
    public let weekDelta: Int
    public let isMe: Bool
}

public struct Board: Decodable, Sendable, Hashable {
    public let scope: BoardScope
    public let college: String?
    public let players: Int
    public let rows: [BoardRow]
    public let me: BoardRow?

    // A college board for someone who hasn't picked a college.
    public var needsCollege: Bool { scope == .college && college == nil }
    public var isEmpty: Bool { rows.isEmpty && !needsCollege }
    // Your row, when it isn't already in the list.
    public var pinnedMe: BoardRow? { rows.contains { $0.isMe } ? nil : me }
}
