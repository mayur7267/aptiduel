"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { Play } from "@/components/icons";

export function AcceptButton({ code, label = "Accept challenge" }: { code: string; label?: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Reset when the page is hidden after navigating, so Back doesn't show "Starting…".
  useEffect(() => () => setBusy(false), []);

  async function accept() {
    setBusy(true);
    setError(null);
    try {
      const { duel_id } = await api.joinChallenge(code);
      router.push(`/duel/${duel_id}`);
    } catch (e) {
      setError((e as Error).message);
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-2.5">
      <div className="flex flex-wrap items-center gap-3">
        <button
          onClick={accept}
          disabled={busy}
          className="pressable flex min-h-[58px] items-center justify-center gap-2.5 self-start rounded-2xl bg-lime px-7 text-[17px] font-bold text-ink [--pop:#5f7710] hover:bg-lime-hover disabled:opacity-70"
        >
          <Play />
          {busy ? "Starting…" : label}
        </button>

        <a
          href={`apticks://c/${code}`}
          className="pressable flex min-h-[58px] items-center justify-center gap-2 rounded-2xl border border-line bg-surface px-6 text-[15px] font-bold text-text hover:bg-raised hover:text-text"
        >
          <span>📱</span> Open in App
        </a>
      </div>
      {error && (
        <p role="alert" className="text-sm text-red-soft">
          {error}
        </p>
      )}
    </div>
  );
}
