"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { account, type Account } from "@/lib/account";
import { ErrorNote } from "@/components/ui";

const field = "h-12 w-full rounded-xl border border-line bg-surface px-3.5 text-[15px] text-text";
const primary = "h-12 rounded-2xl bg-lime px-5 text-[15px] font-bold text-ink hover:bg-lime-hover disabled:opacity-70";
const secondary = "h-12 rounded-2xl bg-raised px-5 text-[15px] font-semibold text-text hover:bg-line disabled:opacity-70";

// Home loads its data on mount, so it picks up the new account.
function useGoHome() {
  const router = useRouter();
  return () => router.push("/");
}

export function AccountPanel() {
  const [acct, setAcct] = useState<Account | null>(null);

  // Next keeps this page mounted (hidden) after you leave, and the account
  // may have changed by the time you're back (signed out, deleted), so
  // drop everything on hide and load it fresh when shown again.
  useEffect(() => {
    let active = true;
    account.get().then((a) => active && setAcct(a), () => {});
    return () => {
      active = false;
      setAcct(null);
    };
  }, []);

  if (!acct) return null;

  return (
    <div className="mt-10 flex flex-col gap-10 border-t border-line pt-8">
      {acct.guest ? <SaveAccount /> : <SignedIn email={acct.email} />}
      <DeleteAccount />
    </div>
  );
}

function SignedIn({ email }: { email: string | null }) {
  const goHome = useGoHome();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function signOut() {
    setBusy(true);
    setError(null);
    try {
      await account.signOut();
      goHome();
    } catch (e) {
      setError((e as Error).message);
      setBusy(false);
    }
  }

  return (
    <section className="flex flex-col gap-3">
      <h2 className="font-display text-lg font-bold">Account</h2>
      <p className="text-sm text-muted">
        Saved to <span className="font-semibold text-text">{email}</span>. Sign in with this email to play on any device.
      </p>
      {error && <ErrorNote message={error} />}
      <button onClick={signOut} disabled={busy} className={`${secondary} self-start`}>
        {busy ? "Signing out…" : "Sign out"}
      </button>
    </section>
  );
}

// Two ways in: save this guest under an email, or sign in to an account
// saved elsewhere (which leaves this guest behind).
function SaveAccount() {
  const goHome = useGoHome();
  const [mode, setMode] = useState<"save" | "signin">("save");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
      goHome();
    });
  }

  return (
    <section className="flex flex-col gap-3">
      <h2 className="font-display text-lg font-bold">{mode === "save" ? "Save your account" : "Sign in"}</h2>
      <p className="text-sm leading-relaxed text-muted">
        {mode === "save"
          ? "You're playing as a guest, so your rating lives only in this browser. Add your email to keep it and play on other devices."
          : "Sign in to an account you saved on another device. This browser's guest progress will be left behind."}
      </p>

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

      <button type="button" onClick={switchMode} className="self-start text-sm font-semibold text-lime hover:text-lime-hover">
        {mode === "save" ? "Already saved an account? Sign in" : "Save this guest instead"}
      </button>
    </section>
  );
}

function DeleteAccount() {
  const goHome = useGoHome();
  const [asking, setAsking] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function remove() {
    setBusy(true);
    setError(null);
    try {
      await account.delete();
      goHome();
    } catch (e) {
      setError((e as Error).message);
      setBusy(false);
    }
  }

  return (
    <section className="flex flex-col gap-3">
      <h2 className="font-display text-lg font-bold">Delete account</h2>
      <p className="text-sm text-muted">Erases your profile, rating and duel history. This can&apos;t be undone.</p>
      {error && <ErrorNote message={error} />}
      {!asking ? (
        <button onClick={() => setAsking(true)} className={`${secondary} self-start text-red-soft`}>
          Delete account
        </button>
      ) : (
        <div className="flex flex-wrap gap-3">
          <button
            onClick={remove}
            disabled={busy}
            className="h-12 rounded-2xl bg-red px-5 text-[15px] font-bold text-ink hover:bg-red-soft disabled:opacity-70"
          >
            {busy ? "Deleting…" : "Delete forever"}
          </button>
          <button onClick={() => setAsking(false)} disabled={busy} className={secondary}>
            Keep my account
          </button>
        </div>
      )}
    </section>
  );
}
