"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api, type Duel } from "@/lib/api";
import { Tiko } from "@/components/tiko";
import { ErrorNote, Spinner } from "@/components/ui";

// Opens today's daily challenge. A run you've already started or
// finished opens straight away; a fresh one waits for you to press Start,
// since the clock begins as soon as the first question opens.
export function DailyStart() {
  const router = useRouter();
  const [duel, setDuel] = useState<Duel | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let active = true;
    api
      .dailyChallenge()
      .then(({ duel_id }) => api.getDuel(duel_id))
      .then((d) => {
        if (!active) return;
        if (d.me.finished) router.replace(`/duel/${d.id}/result`);
        else if (d.me.answered > 0) router.replace(`/duel/${d.id}`);
        else setDuel(d);
      })
      .catch((e: Error) => active && setError(e.message));
    return () => {
      active = false;
      // Next keeps this page mounted (hidden); load fresh when shown again.
      setDuel(null);
    };
  }, [router, attempt]);

  if (error) return <ErrorNote message={error} onRetry={() => (setError(null), setAttempt((n) => n + 1))} />;
  if (!duel) return <Spinner label="Opening today's challenge" />;

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
        onClick={() => router.push(`/duel/${duel.id}`)}
        className="h-12 rounded-2xl bg-text px-6 text-[15px] font-bold text-ink hover:bg-soft"
      >
        Start
      </button>
    </div>
  );
}
