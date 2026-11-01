"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { account, type Account } from "@/lib/account";
import { SignInForm } from "@/components/sign-in-form";
import { ErrorNote } from "@/components/ui";

const secondary = "h-12 rounded-2xl bg-raised px-5 text-[15px] font-semibold text-text hover:bg-line disabled:opacity-70";

// Home loads its data on mount, so it picks up the new account.
function useGoHome() {
  const router = useRouter();
  return () => router.push("/");
}

// `bare` drops the section rule above it, for use inside a dialog.
export function AccountPanel({ bare = false }: { bare?: boolean }) {
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
    <div className={`flex flex-col gap-10 ${bare ? "" : "mt-10 border-t border-line pt-8"}`}>
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

// Save this guest under an email, or sign in to an account saved elsewhere.
function SaveAccount() {
  const goHome = useGoHome();
  return <SignInForm onDone={goHome} />;
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
      <p className="text-sm text-muted">
        Removes your name, college, email and rating, and signs you out for good. Duels you played stay in your
        opponents&apos; history as &quot;Deleted player&quot;. This can&apos;t be undone.
      </p>
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
