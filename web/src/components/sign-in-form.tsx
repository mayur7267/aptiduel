"use client";

import Link from "next/link";
import { useState, type FormEvent } from "react";
import { account } from "@/lib/account";
import { Modal } from "./modal";
import { ErrorNote } from "./ui";

const field = "h-12 w-full rounded-xl border border-line bg-surface px-3.5 text-[15px] text-text";
const primary = "h-12 rounded-2xl bg-lime px-5 text-[15px] font-bold text-ink hover:bg-lime-hover disabled:opacity-70";

const COPY = {
  // The profile page: keep this guest's rating.
  save: {
    save: ["Save your account", "You're playing as a guest, so your rating lives only in this browser. Add your email to keep it and play on other devices."],
    signin: ["Sign in", "Sign in to an account you saved on another device. This browser's guest progress will be left behind."],
    toSignIn: "Already saved an account? Sign in",
    toSave: "Save this guest instead",
  },
  // Before a friend duel: both players need an account.
  duel: {
    save: ["Create your account", "Friend duels are between real accounts, so you both know who you're playing. Add your email: your rating so far comes with you."],
    signin: ["Sign in", "Sign in with the email you used before, on the app or the website."],
    toSignIn: "Already have an account? Sign in",
    toSave: "New here? Create an account",
  },
} as const;

// Two ways in, both with a one-time code by email: save this guest under
// an email (same account and rating), or sign in to an account saved
// elsewhere (which leaves this guest behind).
export function SignInForm({ variant = "save", onDone }: { variant?: keyof typeof COPY; onDone: () => void }) {
  const copy = COPY[variant];
  const [mode, setMode] = useState<"save" | "signin">("save");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [title, intro] = copy[mode];

  function switchMode() {
    setMode(mode === "save" ? "signin" : "save");
    setSent(false);
    setCode("");
    setError(null);
  }

  async function run(fn: () => Promise<void>) {
    setBusy(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      setError((e as Error).message);
    }
    setBusy(false);
  }

  function send(e: FormEvent) {
    e.preventDefault();
    run(async () => {
      if (mode === "save") await account.sendSaveCode(email.trim());
      else await account.sendSignInCode(email.trim());
      setSent(true);
    });
  }

  function confirm(e: FormEvent) {
    e.preventDefault();
    run(async () => {
      if (mode === "save") await account.confirmSaveCode(email.trim(), code.trim());
      else await account.confirmSignInCode(email.trim(), code.trim());
      onDone();
    });
  }

  return (
    <section className="flex flex-col gap-3">
      <h2 className="font-display text-lg font-bold">{title}</h2>
      <p className="text-sm leading-relaxed text-muted">{intro}</p>

      {!sent ? (
        <form onSubmit={send} className="flex flex-col gap-3 sm:flex-row">
          <label htmlFor="email" className="sr-only">Email</label>
          <input
            id="email"
            type="email"
            required
            autoComplete="email"
            placeholder="you@college.edu"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className={field}
          />
          <button type="submit" disabled={busy} className={`${primary} shrink-0`}>
            {busy ? "Sending…" : "Send code"}
          </button>
        </form>
      ) : (
        <form onSubmit={confirm} className="flex flex-col gap-3">
          <p className="text-sm text-soft">
            We sent a code to <span className="font-semibold text-text">{email.trim()}</span>.
          </p>
          <div className="flex flex-col gap-3 sm:flex-row">
            <label htmlFor="code" className="sr-only">Code</label>
            <input
              id="code"
              required
              inputMode="numeric"
              autoComplete="one-time-code"
              pattern="\d{6,10}"
              maxLength={10}
              placeholder="Code from the email"
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
              className={`${field} font-mono tracking-widest`}
            />
            <button type="submit" disabled={busy} className={`${primary} shrink-0`}>
              {busy ? "Checking…" : "Confirm"}
            </button>
          </div>
          <button type="button" onClick={() => setSent(false)} className="self-start text-sm text-muted underline">
            Use a different email
          </button>
        </form>
      )}

      {error && <ErrorNote message={error} />}

      <p className="text-xs leading-relaxed text-faint">
        We use your email only to sign you in. See our{" "}
        <Link href="/privacy" className="underline hover:text-text">privacy policy</Link>.
      </p>

      <button type="button" onClick={switchMode} className="self-start text-sm font-semibold text-lime hover:text-lime-hover">
        {mode === "save" ? copy.toSignIn : copy.toSave}
      </button>
    </section>
  );
}

// The sign-in step before a friend duel, as a dialog.
export function DuelSignIn({ open, onClose, onDone }: { open: boolean; onClose: () => void; onDone: () => void }) {
  return (
    <Modal open={open} onClose={onClose} title="Sign in to duel friends">
      {open && <SignInForm variant="duel" onDone={onDone} />}
    </Modal>
  );
}
