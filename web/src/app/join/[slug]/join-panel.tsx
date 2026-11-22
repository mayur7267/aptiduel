"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api, type Me } from "@/lib/api";
import { hasSavedSession } from "@/lib/supabase";
import { Bolt } from "@/components/icons";

// Join this college and go straight into a duel. Someone who already plays
// for another college is asked before they move; someone already here just
// plays.
export function JoinPanel({ id, name }: { id: number; name: string }) {
  const router = useRouter();
  // undefined while we look, null for a newcomer.
  const [me, setMe] = useState<Me | null | undefined>(undefined);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const newcomer = !hasSavedSession();
    // A newcomer who came in through a campus link, noted once.
    if (newcomer) api.noteArrival("campus", String(id)).catch(() => {});
    (newcomer ? Promise.resolve(null) : api.getMe()).then(setMe, () => setMe(null));
  }, [id]);

  async function join() {
    setBusy(true);
    setError(null);
    try {
      await api.joinCollege(id);
      router.push("/play");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Couldn't join. Try again.");
      setBusy(false);
    }
  }

  const here = me?.college_id === id;
  const elsewhere = !!me?.college_id && !here;
  const button =
    "pressable flex h-14 items-center justify-center gap-2.5 self-stretch rounded-2xl bg-lime px-8 text-[17px] font-bold text-ink [--pop:#5f7710] hover:text-ink disabled:opacity-60 sm:self-start";

  if (here) {
    return (
      <div className="flex flex-col gap-3">
        <p className="text-[15px] font-semibold text-lime">You&apos;re already on {name}&apos;s board.</p>
        <div className="flex flex-wrap gap-3">
          <Link href="/play" className={button}>
            <Bolt size={20} strokeWidth={2.4} />
            Play a duel
          </Link>
          <Link href="/leaderboard" className="flex h-14 items-center rounded-2xl border border-line bg-surface px-6 font-semibold text-text hover:bg-raised">
            See the board
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      {elsewhere && (
        <p className="max-w-[520px] rounded-2xl border border-line bg-surface px-4 py-3 text-[15px] text-muted">
          You play for <span className="font-semibold text-text">{me?.college}</span> now. Joining moves you to {name}&apos;s board.
        </p>
      )}
      <button type="button" onClick={join} disabled={busy || me === undefined} className={button}>
        <Bolt size={20} strokeWidth={2.4} />
        {busy ? "Joining…" : elsewhere ? "Switch college and play" : "Join and play a duel"}
      </button>
      {error && <p className="text-sm text-red">{error}</p>}
      <Link href="/profile" className="-mt-1 self-center text-sm font-semibold text-muted hover:text-text sm:self-start">
        Not your college? Find yours
      </Link>
    </div>
  );
}
