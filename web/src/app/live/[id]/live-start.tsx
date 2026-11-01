"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { use, useEffect, useState } from "react";
import { useLiveState } from "@/lib/live";
import { ErrorNote, Avatar, Spinner } from "@/components/ui";

// Both players are in: see each other, count down together, then the
// race starts on the duel screen at the same moment for both.
export function LiveStart({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const { state, error, serverNow } = useLiveState(id, 700);
  const [now, setNow] = useState(0);

  useEffect(() => {
    const t = setInterval(() => setNow(serverNow()), 100);
    return () => clearInterval(t);
  }, [serverNow]);

  const status = state?.status;
  const code = state?.code;
  // A moment after the start, so the server has opened the first question.
  const started = !!state?.starts_at_ms && now > state.starts_at_ms + 250;
  useEffect(() => {
    if ((status === "waiting" || status === "closed") && code) router.replace(`/c/${code}`);
    else if (status === "done") router.replace(`/duel/${id}/result`);
    else if (status === "async" || status === "playing" || (status === "starting" && started)) router.replace(`/duel/${id}`);
  }, [status, code, started, id, router]);

  if (!state) {
    return error ? (
      <div className="flex flex-col gap-4 pt-10">
        <ErrorNote message={error} onRetry={() => location.reload()} />
        <Link href="/" className="text-sm font-semibold">Back to home</Link>
      </div>
    ) : (
      <Spinner label="Loading duel" />
    );
  }

  const left = state.starts_at_ms ? Math.max(0, Math.ceil((state.starts_at_ms - (now || serverNow())) / 1000)) : 5;
  const opp = state.opponent?.name ?? "…";
  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-8 py-10 text-center" aria-live="polite">
      <span className="flex items-center gap-2 rounded-full bg-orange-tint px-3 py-1.5 text-[13px] font-bold text-orange">
        <span className="size-2 rounded-full bg-orange motion-safe:animate-pulse" />
        Live duel
      </span>
      <div className="grid w-full max-w-sm grid-cols-[1fr_auto_1fr] items-center gap-3">
        <div className="flex min-w-0 flex-col items-center gap-2 motion-safe:animate-rise">
          <Avatar name={state.me.name} size={72} ring="border-2 border-lime" />
          <span className="max-w-full truncate font-bold">You</span>
        </div>
        <span className="-rotate-6 rounded-md bg-raised px-2.5 py-1.5 font-display text-base font-bold text-soft">VS</span>
        <div className="flex min-w-0 flex-col items-center gap-2 motion-safe:animate-rise" style={{ animationDelay: "150ms" }}>
          <Avatar name={opp} size={72} ring="border-2 border-orange" />
          <span className="max-w-full truncate font-bold">{opp}</span>
        </div>
      </div>
      {left > 3 ? (
        <p className="font-display text-2xl font-bold">Get ready…</p>
      ) : (
        <span key={left} className="font-display text-[96px] leading-none font-bold text-lime motion-safe:animate-pop">
          {Math.max(1, left)}
        </span>
      )}
      <p className="max-w-xs text-sm text-muted">
        Same 5 questions, starting together. Go at your own pace: right and fast wins, and you&apos;ll see how
        {` ${opp}`} is doing as you play.
      </p>
    </div>
  );
}
