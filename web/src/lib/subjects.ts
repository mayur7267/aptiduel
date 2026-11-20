"use client";

import { useCallback, useSyncExternalStore } from "react";

// What a Quick Match can be about (supabase/migrations/0022_subjects.sql,
// 0024_english.sql). GK is shown as coming soon.
export type Subject = "aptitude" | "coding" | "english";
export type SubjectTab = Subject | "english" | "gk";

export const SUBJECT_TABS: { id: SubjectTab; label: string; soon?: true }[] = [
  { id: "aptitude", label: "Aptitude" },
  { id: "coding", label: "Coding" },
  { id: "english", label: "English" },
  { id: "gk", label: "GK", soon: true },
];

// Each coding question is one program, printed in every language below,
// so two players reading different languages can share a duel.
export type CodeLang = "c" | "cpp" | "java" | "python" | "pseudo";
export type Code = Record<CodeLang, string>;

export const CODE_LANGS: { id: CodeLang; label: string; file: string }[] = [
  { id: "c", label: "C", file: "main.c" },
  { id: "cpp", label: "C++", file: "main.cpp" },
  { id: "java", label: "Java", file: "Main.java" },
  { id: "python", label: "Python", file: "main.py" },
  { id: "pseudo", label: "Pseudo", file: "pseudocode" },
];

// Remembered per browser. Storage can be missing (private windows,
// blocked site data), so every read and write is guarded and the
// defaults still work.
function stored<T extends string>(key: string, allowed: readonly T[], fallback: T) {
  const listeners = new Set<() => void>();
  const read = (): T => {
    try {
      const v = window.localStorage.getItem(key);
      return v && (allowed as readonly string[]).includes(v) ? (v as T) : fallback;
    } catch {
      return fallback;
    }
  };
  let current: T | null = null;
  return {
    get: () => (current ??= read()),
    server: () => fallback,
    set(v: T) {
      current = v;
      try {
        window.localStorage.setItem(key, v);
      } catch {}
      listeners.forEach((l) => l());
    },
    subscribe(l: () => void) {
      listeners.add(l);
      return () => listeners.delete(l);
    },
  };
}

const subjectStore = stored<SubjectTab>("apticks-subject", ["aptitude", "coding", "english", "gk"], "aptitude");
const langStore = stored<CodeLang>("apticks-code-lang", ["c", "cpp", "java", "python", "pseudo"], "c");

export function useSubjectTab(): [SubjectTab, (s: SubjectTab) => void] {
  const v = useSyncExternalStore(subjectStore.subscribe, subjectStore.get, subjectStore.server);
  return [v, useCallback((s: SubjectTab) => subjectStore.set(s), [])];
}

// The subject a new friend duel starts in: the one open on the Quick
// Match card, if it can be played (English and GK are coming soon).
export function roomSubject(): Subject {
  const t = subjectStore.get();
  return t === "gk" ? "aptitude" : t;
}

export function useCodeLang(): [CodeLang, (l: CodeLang) => void] {
  const v = useSyncExternalStore(langStore.subscribe, langStore.get, langStore.server);
  return [v, useCallback((l: CodeLang) => langStore.set(l), [])];
}

// Whether the player has picked a language yet (first visit to Coding).
export function hasPickedLang(): boolean {
  try {
    return window.localStorage.getItem("apticks-code-lang") !== null;
  } catch {
    return false;
  }
}
