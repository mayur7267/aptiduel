import Foundation
import Testing
@testable import Domain

// Subjects (0022_subjects.sql): coding questions carry the program in every
// language, and an older app copes with whatever subject comes next.
struct SubjectTests {
    private func decode<T: Decodable>(_ json: String) throws -> T {
        try Wire.decoder.decode(T.self, from: Data(json.utf8))
    }

    @Test func aCodingQuestionCarriesItsProgram() throws {
        let v: QuestionView = try decode("""
        {"done": false, "q_index": 0, "total": 5, "section": "coding", "topic": "Loops", "companies": [],
         "difficulty": 1, "body": "What does this code print?", "figure": null,
         "code": {"c": "int s = 0;", "cpp": "int s = 0;", "java": "int s = 0;", "python": "s = 0", "pseudo": "Integer s = 0"},
         "options": ["10", "6", "15", "4"], "option_figures": null, "time_limit_ms": 40000, "remaining_ms": 40000, "score": 0}
        """)
        guard case let .question(q) = v else { Issue.record("expected a question"); return }
        #expect(q.code?.text(.python) == "s = 0")
        #expect(q.code?.text(.pseudo) == "Integer s = 0")
    }

    @Test func anAptitudeQuestionHasNoProgram() throws {
        let v: QuestionView = try decode("""
        {"done": false, "q_index": 0, "total": 5, "section": "quant", "topic": "Ages", "companies": null, "difficulty": 1,
         "body": "How old?", "figure": null, "options": ["1", "2", "3", "4"], "option_figures": null,
         "time_limit_ms": 30000, "remaining_ms": 30000, "score": 0}
        """)
        guard case let .question(q) = v else { Issue.record("expected a question"); return }
        #expect(q.code == nil)
    }

    @Test func subjectsDecodeAndUnknownOnesReadAsAptitude() throws {
        let known: [Subject] = try decode(#"["aptitude", "coding", "english"]"#)
        #expect(known == [.aptitude, .coding, .english])
        let later: Subject = try decode(#""gk""#)
        #expect(later == .aptitude)
    }

    @Test func ratingsPerSubject() throws {
        let r: SubjectRatings = try decode(#"{"aptitude": {"rating": 1180, "games": 12}, "coding": {"rating": 1021, "games": 3}}"#)
        #expect(r.coding.rating == 1021)
        #expect(r.aptitude.games == 12)
    }

    // Same cases as overallRating in web/tests/lib.test.mjs.
    @Test func overallWeighsEachSubjectByGames() throws {
        let three: SubjectRatings = try decode(#"{"aptitude": {"rating": 1200, "games": 3}, "coding": {"rating": 1000, "games": 1}, "english": {"rating": 1000, "games": 0}}"#)
        #expect(SubjectRatings.overall(three, aptitude: 1200) == 1150)
        let even: SubjectRatings = try decode(#"{"aptitude": {"rating": 1020, "games": 1}, "coding": {"rating": 982, "games": 1}, "english": {"rating": 978, "games": 1}}"#)
        #expect(SubjectRatings.overall(even, aptitude: 1020) == 993)
        let fresh: SubjectRatings = try decode(#"{"aptitude": {"rating": 1000, "games": 0}, "coding": {"rating": 1000, "games": 0}}"#)
        #expect(SubjectRatings.overall(fresh, aptitude: 1000) == 1000)
        #expect(SubjectRatings.overall(nil, aptitude: 1040) == 1040)
        let older: SubjectRatings = try decode(#"{"aptitude": {"rating": 1100, "games": 1}, "coding": {"rating": 900, "games": 1}}"#)
        #expect(SubjectRatings.overall(older, aptitude: 1100) == 1000)
    }

    @Test func tabsAndLanguages() {
        #expect(SubjectTab.allCases.filter(\.soon) == [.gk])
        #expect(SubjectTab.coding.subject == .coding)
        #expect(CodeLang.allCases.map(\.file) == ["main.c", "main.cpp", "Main.java", "main.py", "pseudocode"])
    }
}
