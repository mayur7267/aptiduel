"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api, type Duel } from "@/lib/api";
import { Tiko } from "@/components/tiko";
import { ErrorNote, Spinner } from "@/components/ui";

// Opens today's daily challenge. A run you've finished opens its result;
// otherwise you see what it is and press Start, since the clock begins as
// soon as the first question opens. Today's run is only made on Start, so
// looking at this page doesn't count as starting a game.
export function DailyStart() {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let active = true;
    api
      .getMe()
      .then(async (me) => {
        if (!active) return;
        if (me.quests.daily === 0) return setReady(true);
        const d: Duel = await api.getDuel((await api.dailyChallenge()).duel_id);
        if (active) router.replace(d.me.finished ? `/duel/${d.id}/result` : `/duel/${d.id}`);
      })
      .catch((e: Error) => active && setError(e.message));
    return () => {
      active = false;
      // Next keeps this page mounted (hidden); load fresh when shown again.
      setReady(false);
      setBusy(false);
    };
  }, [router, attempt]);

  async function start() {
    setBusy(true);
    try {
      const { duel_id } = await api.dailyChallenge();
      router.push(`/duel/${duel_id}`);
    } catch (e) {
      setError((e as Error).message);
      setBusy(false);
    }
  }

  if (error) return <ErrorNote message={error} onRetry={() => (setError(null), setAttempt((n) => n + 1))} />;
  if (!ready) return <Spinner label="Opening today's challenge" />;

  return (
    <div className="flex flex-col items-start gap-4 rounded-[22px] border-2 border-violet-strong bg-[linear-gradient(150deg,#251f4a_0%,#151a26_70%)] p-6">
      <Tiko mood="wave" size={76} />
      <div className="flex flex-col gap-1.5">
        <h1 className="font-display text-2xl font-bold">Today&apos;s Daily Challenge</h1>
        <p className="text-[15px] text-violet-soft/80">
          5 questions, the same for everyone today. You get one try, and the clock starts when you press Start.
        </p>
      </div>
      <button
        onClick={start}
        disabled={busy}
        className="h-12 rounded-2xl bg-text px-6 text-[15px] font-bold text-ink hover:bg-soft disabled:opacity-70"
      >
        {busy ? "Starting…" : "Start"}
      </button>
    </div>
  );
}
