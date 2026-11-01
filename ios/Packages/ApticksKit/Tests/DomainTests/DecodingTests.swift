import Foundation
import Testing
@testable import Domain

// The database's JSON shapes (see supabase/migrations) decode as expected.
struct DecodingTests {
    private func decode<T: Decodable>(_ json: String) throws -> T {
        try Wire.decoder.decode(T.self, from: Data(json.utf8))
    }

    @Test func questionViewDone() throws {
        let v: QuestionView = try decode(#"{"done": true, "score": 486}"#)
        #expect(v == .done(score: 486))
    }

    @Test func questionViewWithFigures() throws {
        let v: QuestionView = try decode("""
        {"done": false, "q_index": 1, "total": 5, "section": "reasoning", "topic": "Figure Series", "companies": null,
         "difficulty": 2, "body": "Which figure comes next?", "figure": "<svg viewBox=\\"0 0 10 10\\"></svg>",
         "options": ["A", "B", "C", "D"], "option_figures": null, "time_limit_ms": 45000, "remaining_ms": 44200, "score": 141}
        """)
        guard case let .question(q) = v else { Issue.record("expected a question"); return }
        #expect(q.qIndex == 1)
        #expect(q.timeLimitMs == 45_000)
        #expect(q.companies == nil)
    }

    @Test func boardScopeAndPinnedRow() throws {
        let b: Board = try decode("""
        {"scope": "india", "college": null, "players": 2, "me": {"rank": 9, "name": "Me", "rating": 1100, "college": null,
         "grad_year": null, "week_delta": 0, "is_me": true},
         "rows": [{"rank": 1, "name": "A", "rating": 1700, "college": "VIT", "grad_year": 2026, "week_delta": 12, "is_me": false}]}
        """)
        #expect(b.scope == .india)
        #expect(b.pinnedMe?.rank == 9)
        #expect(!b.needsCollege)
    }

    @Test func collegeBoardWithoutCollege() throws {
        let b: Board = try decode(#"{"scope": "college", "college": null, "players": 0, "rows": [], "me": null}"#)
        #expect(b.needsCollege)
        #expect(!b.isEmpty)
    }

    @Test func nullChallengeStatus() throws {
        let s: ChallengeStatus? = try decode("null")
        #expect(s == nil)
    }

    @Test func timestampsWithMicroseconds() {
        #expect(parseTimestamp("2026-10-29T10:15:30.123456+00:00") != nil)
        #expect(parseTimestamp("2026-10-29T10:15:30+05:30") != nil)
        #expect(parseTimestamp("yesterday") == nil)
    }
}
