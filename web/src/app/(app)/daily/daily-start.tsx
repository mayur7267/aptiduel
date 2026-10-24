"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { ErrorNote, Spinner } from "@/components/ui";

// Opens today's daily challenge, or the finished one if already played.
export function DailyStart() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let active = true;
    api
      .dailyChallenge()
      .then(({ duel_id }) => active && router.replace(`/duel/${duel_id}`))
      .catch((e: Error) => active && setError(e.message));
    return () => {
      active = false;
    };
  }, [router, attempt]);

  if (error) return <ErrorNote message={error} onRetry={() => (setError(null), setAttempt((n) => n + 1))} />;
  return <Spinner label="Opening today's challenge" />;
}
