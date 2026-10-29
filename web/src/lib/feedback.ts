"use client";

// Opens the feedback form (components/feedback-dialog.tsx) from anywhere:
// a problem report, a feature idea, or a report about one question.

export type FeedbackKind = "bug" | "idea" | "question";
export type FeedbackRequest = { kind: FeedbackKind; context?: Record<string, string | number>; seq: number };

type State = { request: FeedbackRequest | null };

// The server never shows the form; one fixed object keeps React from looping.
const SERVER_STATE: State = { request: null };
let state: State = SERVER_STATE;
let seq = 0;
const listeners = new Set<() => void>();

function set(next: State) {
  state = next;
  listeners.forEach((l) => l());
}

export const feedbackStore = {
  subscribe(l: () => void) {
    listeners.add(l);
    return () => listeners.delete(l);
  },
  get: () => state,
  serverGet: () => SERVER_STATE,
};

export function openFeedback(kind: FeedbackKind, context?: FeedbackRequest["context"]) {
  set({ request: { kind, context, seq: ++seq } });
}

export function closeFeedback() {
  set({ request: null });
}

// Sent with every message, so a problem can be reproduced.
export function feedbackContext(extra?: FeedbackRequest["context"]) {
  const build = process.env.NEXT_PUBLIC_VERCEL_GIT_COMMIT_SHA?.slice(0, 7);
  return {
    page: window.location.pathname,
    screen: `${window.innerWidth}×${window.innerHeight}`,
    browser: navigator.userAgent.slice(0, 200),
    ...(build ? { build } : {}),
    ...extra,
  };
}
