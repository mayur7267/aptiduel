"use client";

import { useEffect, useRef, useState, useSyncExternalStore, type FormEvent } from "react";
import { account } from "@/lib/account";
import { api } from "@/lib/api";
import { closeFeedback, feedbackContext, feedbackStore, type FeedbackKind, type FeedbackRequest } from "@/lib/feedback";
import { Close } from "./icons";
import { Tiko, type TikoMood } from "./tiko";

// The feedback form: report a problem, suggest a feature, or report one
// question. It goes to the team's inbox (supabase/functions/feedback-mail)
// with the page and browser attached. Mounted once in the root layout and
// opened with openFeedback().

const COPY: Record<FeedbackKind, { title: string; hint: string; placeholder: string; mood: TikoMood }> = {
  bug: {
    title: "Report a problem",
    hint: "What went wrong, and what did you expect to happen?",
    placeholder: "The timer froze on question 3 when I…",
    mood: "confused",
  },
  idea: {
    title: "Suggest a feature",
    hint: "What would make Apticks better for you?",
    placeholder: "It would be great if I could…",
    mood: "think",
  },
  question: {
    title: "Report this question",
    hint: "Is the answer wrong, or is something unclear?",
    placeholder: "Option B should be right because…",
    mood: "point",
  },
};

const field = "w-full rounded-xl border border-line bg-ink px-3.5 text-[15px] text-text placeholder:text-faint";

export function FeedbackDialog() {
  const { request } = useSyncExternalStore(feedbackStore.subscribe, feedbackStore.get, feedbackStore.serverGet);
  const dialog = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const d = dialog.current;
    if (!d) return;
    if (request && !d.open) d.showModal();
    if (!request && d.open) d.close();
  }, [request]);

  return (
    <dialog
      ref={dialog}
      onClose={closeFeedback}
      aria-label="Send feedback"
      className="m-auto w-[min(520px,calc(100vw-32px))] rounded-[22px] border-2 border-line bg-surface p-0 text-text sticker backdrop:bg-ink/75 backdrop:backdrop-blur-sm"
    >
      {/* Keyed so every opening starts with a fresh form. */}
      {request && <FeedbackForm key={request.seq} request={request} />}
    </dialog>
  );
}

function FeedbackForm({ request }: { request: FeedbackRequest }) {
  const [kind, setKind] = useState<FeedbackKind>(request.kind);
  const [message, setMessage] = useState("");
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "sending" | "sent">("idle");
  const [error, setError] = useState<string | null>(null);
  const copy = COPY[kind];

  // A saved account's email fills in the reply address.
  useEffect(() => {
    let active = true;
    account.get().then(
      (a) => active && a.email && setEmail((e) => e || a.email || ""),
      () => {},
    );
    return () => {
      active = false;
    };
  }, []);

  async function send(e: FormEvent) {
    e.preventDefault();
    setStatus("sending");
    setError(null);
    try {
      await api.submitFeedback(kind, message.trim(), email.trim() || null, feedbackContext(request.context));
      setStatus("sent");
    } catch (err) {
      setError((err as Error).message);
      setStatus("idle");
    }
  }

  if (status === "sent") {
    return (
      <div className="flex flex-col items-center gap-3 p-8 text-center">
        <Tiko mood="cheer" size={92} className="motion-safe:animate-pop" />
        <h2 className="font-display text-xl font-bold">Thank you!</h2>
        <p className="max-w-xs text-sm text-muted">
          We read every message{email.trim() ? ", and we'll reply if we need more details" : ""}.
        </p>
        <button
          onClick={closeFeedback}
          autoFocus
          className="mt-2 h-11 rounded-xl bg-lime px-6 text-sm font-bold text-ink hover:bg-lime-hover"
        >
          Done
        </button>
      </div>
    );
  }

  return (
    <form onSubmit={send} className="flex flex-col gap-4 p-5 sm:p-6">
      <div className="flex items-start gap-3">
        <Tiko mood={copy.mood} size={56} interactive={false} className="shrink-0" />
        <div className="min-w-0 flex-1">
          <h2 className="font-display text-lg font-bold">{copy.title}</h2>
          <p className="text-sm text-muted">{copy.hint}</p>
        </div>
        <button
          type="button"
          onClick={closeFeedback}
          aria-label="Close"
          className="flex size-9 shrink-0 items-center justify-center rounded-full border border-line hover:bg-raised"
        >
          <Close size={16} strokeWidth={2.4} />
        </button>
      </div>

      {request.kind !== "question" && (
        <div role="group" aria-label="What is this about?" className="grid grid-cols-2 rounded-xl border border-line bg-ink p-1">
          {(["bug", "idea"] as const).map((k) => (
            <button
              key={k}
              type="button"
              aria-pressed={kind === k}
              onClick={() => setKind(k)}
              className={`h-10 rounded-lg text-sm font-bold transition ${kind === k ? "bg-raised text-text" : "text-muted hover:text-text"}`}
            >
              {k === "bug" ? "🐞 Problem" : "💡 Idea"}
            </button>
          ))}
        </div>
      )}

      {request.kind === "question" && request.context?.body && (
        <p className="rounded-xl border border-line bg-raised px-3.5 py-2.5 text-sm text-soft">
          <span className="font-semibold text-muted">Q{request.context.question} · </span>
          {String(request.context.body)}
        </p>
      )}

      <label className="flex flex-col gap-1.5">
        <span className="sr-only">Message</span>
        <textarea
          required
          autoFocus
          minLength={3}
          maxLength={2000}
          rows={5}
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder={copy.placeholder}
          className={`${field} resize-y py-3 leading-relaxed`}
        />
        <span className="self-end text-xs text-faint tabular-nums">{message.length}/2000</span>
      </label>

      <label className="flex flex-col gap-1.5">
        <span className="text-sm font-semibold">
          Your email <span className="font-normal text-muted">(optional, so we can reply)</span>
        </span>
        <input
          type="email"
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="you@college.edu"
          className={`${field} h-11`}
        />
      </label>

      {error && (
        <p role="alert" className="text-sm text-red-soft">
          {error}
        </p>
      )}

      <button
        type="submit"
        disabled={status === "sending" || message.trim().length < 3}
        className="pressable h-12 rounded-[14px] bg-lime text-[15px] font-bold text-ink [--pop:#5f7710] hover:bg-lime-hover disabled:opacity-60"
      >
        {status === "sending" ? "Sending…" : "Send"}
      </button>
      <p className="-mt-1 text-center text-xs text-faint">The page you&apos;re on and your browser are sent along, to help us fix things.</p>
    </form>
  );
}
