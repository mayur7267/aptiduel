import type { Subject } from "./subjects";

// How each subject is described on invites and link previews.
export const SUBJECT_INFO: Record<Subject, { duel: string; what: string; live: string; points: string }> = {
  aptitude: {
    duel: "an aptitude duel",
    what: "5 placement-style questions, about 3 minutes",
    live: "Join and answer the same 5 placement aptitude questions at the same time. About 3 minutes.",
    points: "Quant and reasoning",
  },
  coding: {
    duel: "a coding duel",
    what: "5 short programs, say what each one prints, about 4 minutes",
    live: "Join and read the same 5 short programs at the same time: say what each one prints. C, C++, Java, Python or pseudocode, about 4 minutes.",
    points: "C, C++, Java, Python or pseudocode",
  },
  english: {
    duel: "an English duel",
    what: "5 English questions on vocabulary and grammar, about 3 minutes",
    live: "Join and answer the same 5 English questions at the same time: vocabulary, grammar and usage. About 3 minutes.",
    points: "Vocabulary, grammar, usage",
  },
};
