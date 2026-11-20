"use client";

import { Fragment, type ReactNode } from "react";
import { CODE_LANGS, useCodeLang, type Code, type CodeLang } from "@/lib/subjects";

// A coding question's program, like a tab in an editor: the file name,
// a language switch (the same program in every language, so switching is
// never an advantage), line numbers and light syntax colours.
export function CodeBlock({ code, className = "" }: { code: Code; className?: string }) {
  const [lang, setLang] = useCodeLang();
  const meta = CODE_LANGS.find((l) => l.id === lang) ?? CODE_LANGS[0];
  const lines = (code[lang] ?? code.c).split("\n");

  return (
    <div className={`overflow-hidden rounded-2xl border-2 border-line bg-bar ${className}`}>
      <div className="flex items-center justify-between gap-2 border-b-2 border-line bg-surface pr-1.5">
        <span className="-mb-0.5 rounded-t-[10px] border-b-2 border-violet px-3.5 py-2 font-mono text-xs font-bold text-soft">
          {meta.file}
        </span>
        <label className="flex items-center gap-1.5 text-xs text-muted">
          <span className="sr-only">Language</span>
          <select
            value={lang}
            onChange={(e) => setLang(e.target.value as CodeLang)}
            className="h-8 cursor-pointer rounded-lg border border-line bg-raised px-2 font-mono text-xs font-bold text-text outline-none focus-visible:border-violet"
          >
            {CODE_LANGS.map((l) => (
              <option key={l.id} value={l.id}>
                {l.label}
              </option>
            ))}
          </select>
        </label>
      </div>
      <pre className="overflow-x-auto py-3 font-mono text-[13px] leading-[1.65] sm:text-sm">
        <code className="grid grid-cols-[auto_1fr]">
          {lines.map((line, i) => (
            <Fragment key={i}>
              <span aria-hidden="true" className="select-none pr-3.5 pl-3 text-right text-faint/70">
                {i + 1}
              </span>
              <span className="pr-4 whitespace-pre text-soft">{highlight(line, lang)}</span>
            </Fragment>
          ))}
        </code>
      </pre>
    </div>
  );
}

const KEYWORDS: Record<CodeLang, Set<string>> = {
  c: new Set(["int", "void", "for", "while", "if", "else", "return", "break", "continue"]),
  cpp: new Set(["int", "void", "for", "while", "if", "else", "return", "break", "continue", "cout", "using", "namespace"]),
  java: new Set(["int", "void", "static", "for", "while", "if", "else", "return", "break", "continue", "System"]),
  python: new Set(["for", "in", "while", "if", "elif", "else", "return", "break", "continue", "def", "and", "or", "not"]),
  pseudo: new Set(["Integer", "for", "to", "down", "step", "end", "while", "if", "else", "return", "break", "continue", "function", "print", "and", "or", "mod"]),
};

const TOKEN = /(\/\/.*$|#.*$)|("(?:[^"\\]|\\.)*")|(\b\d+\b)|([A-Za-z_]\w*)|(\s+|.)/g;

function highlight(line: string, lang: CodeLang): ReactNode[] {
  const out: ReactNode[] = [];
  let m: RegExpExecArray | null;
  let k = 0;
  TOKEN.lastIndex = 0;
  while ((m = TOKEN.exec(line))) {
    const [text, comment, str, num, word] = m;
    // `#` is only a comment in Python (C's #include never shows here).
    if (comment && !(comment.startsWith("#") && lang !== "python")) {
      out.push(<span key={k++} className="text-faint italic">{text}</span>);
    } else if (str) {
      out.push(<span key={k++} className="text-lime">{text}</span>);
    } else if (num) {
      out.push(<span key={k++} className="text-orange">{text}</span>);
    } else if (word && KEYWORDS[lang].has(word)) {
      out.push(<span key={k++} className="font-semibold text-violet">{text}</span>);
    } else if (word && line[TOKEN.lastIndex] === "(") {
      out.push(<span key={k++} className="text-violet-soft">{text}</span>);
    } else {
      out.push(text);
    }
  }
  return out;
}
