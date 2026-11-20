import DesignSystem
import Domain
import SwiftUI

// A coding question's program, like a tab in an editor (port of
// web/src/components/code-block.tsx): the file name, a language menu (the
// same program in every language, so switching is never an advantage),
// line numbers and light syntax colours. The language is the one picked on
// Home's Coding card, and changing it here changes it there too.
struct CodeBlock: View {
    let code: CodeSet
    @AppStorage("apticks-code-lang") private var storedLang = CodeLang.c.rawValue

    private var lang: CodeLang { CodeLang(rawValue: storedLang) ?? .c }

    var body: some View {
        let lines = code.text(lang).components(separatedBy: "\n")
        let numberWidth: CGFloat = lines.count >= 10 ? 18 : 10
        VStack(spacing: 0) {
            HStack {
                Text(lang.file)
                    .font(.mono(12))
                    .foregroundStyle(Theme.soft)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.violet).frame(height: 2) }
                Spacer()
                Menu {
                    Picker("Language", selection: $storedLang) {
                        ForEach(CodeLang.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(lang.label).font(.mono(12))
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.raised))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                }
                .accessibilityLabel("Language, \(lang.label)")
                .padding(.trailing, 6)
            }
            .background(Theme.surface)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 2) }

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(lines.indices, id: \.self) { i in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(i + 1)")
                                .font(.mono(13, .regular))
                                .foregroundStyle(Theme.faint.opacity(0.7))
                                .frame(width: numberWidth, alignment: .trailing)
                            Text(Self.highlight(lines[i], lang))
                                .font(.mono(13, .regular))
                                .fixedSize()
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Theme.bar)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line, lineWidth: 2))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Code in \(lang.label)")
        .accessibilityValue(code.text(lang))
    }

    static let keywords: [CodeLang: Set<String>] = [
        .c: ["int", "void", "for", "while", "if", "else", "return", "break", "continue"],
        .cpp: ["int", "void", "for", "while", "if", "else", "return", "break", "continue", "cout", "using", "namespace"],
        .java: ["int", "void", "static", "for", "while", "if", "else", "return", "break", "continue", "System"],
        .python: ["for", "in", "while", "if", "elif", "else", "return", "break", "continue", "def", "and", "or", "not"],
        .pseudo: ["Integer", "for", "to", "down", "step", "end", "while", "if", "else", "return", "break", "continue",
                  "function", "print", "and", "or", "mod"],
    ]

    // Keywords violet, function names light violet, numbers orange,
    // strings lime, comments faint.
    static func highlight(_ line: String, _ lang: CodeLang) -> AttributedString {
        var out = AttributedString()
        func push(_ s: Substring, _ color: Color, bold: Bool = false) {
            var a = AttributedString(String(s))
            a.foregroundColor = color
            if bold { a.font = .mono(13, .semibold) }
            out += a
        }
        let words = keywords[lang] ?? []
        var i = line.startIndex
        while i < line.endIndex {
            let rest = line[i...]
            if rest.hasPrefix("//") || (lang == .python && rest.hasPrefix("#")) {
                push(rest, Theme.faint)
                break
            }
            let ch = line[i]
            if ch == "\"" {
                var j = line.index(after: i)
                while j < line.endIndex, line[j] != "\"" {
                    if line[j] == "\\" { j = line.index(after: j) }
                    if j < line.endIndex { j = line.index(after: j) }
                }
                if j < line.endIndex { j = line.index(after: j) }
                push(line[i..<j], Theme.lime)
                i = j
            } else if ch.isNumber {
                var j = i
                while j < line.endIndex, line[j].isNumber { j = line.index(after: j) }
                push(line[i..<j], Theme.orange)
                i = j
            } else if ch.isLetter || ch == "_" {
                var j = i
                while j < line.endIndex, line[j].isLetter || line[j].isNumber || line[j] == "_" { j = line.index(after: j) }
                let word = line[i..<j]
                if words.contains(String(word)) {
                    push(word, Theme.violet, bold: true)
                } else if j < line.endIndex, line[j] == "(" {
                    push(word, Theme.violetSoft)
                } else {
                    push(word, Theme.soft)
                }
                i = j
            } else {
                push(line[i...i], Theme.soft)
                i = line.index(after: i)
            }
        }
        return out
    }
}
