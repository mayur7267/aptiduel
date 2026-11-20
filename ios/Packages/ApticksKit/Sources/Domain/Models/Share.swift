import Foundation

// What was shared and how, for the share counts (0021_share_cards.sql).
public enum ShareKind: String, Sendable, Hashable {
    case daily, story, challenge
}

public enum ShareChannel: String, Sendable, Hashable {
    case whatsapp, share, copy, download
}
