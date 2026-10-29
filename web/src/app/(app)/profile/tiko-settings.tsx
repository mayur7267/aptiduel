"use client";

import Link from "next/link";
import { useSyncExternalStore } from "react";
import { companionStore, setTikoOff } from "@/lib/companion";

// Replay the home tour, or switch Tiko the companion off and on.
// `bare` drops the section rule above it, for use inside a dialog.
export function TikoSettings({ bare = false }: { bare?: boolean }) {
  const { off } = useSyncExternalStore(companionStore.subscribe, companionStore.get, companionStore.serverGet);
  return (
    <section className={`flex flex-col gap-3 ${bare ? "" : "mt-10 border-t border-line pt-8"}`}>
      <h2 className="font-display text-lg font-bold">Tiko</h2>
      <p className="text-sm text-muted">Your little buddy in the corner. Tap Tiko for a tip.</p>
      <div className="flex flex-wrap gap-3">
        <Link
          href="/?tour=1"
          className="flex h-12 items-center rounded-2xl bg-raised px-5 text-[15px] font-semibold text-text hover:bg-line hover:text-text"
        >
          Replay the app tour
        </Link>
        <button
          onClick={() => setTikoOff(!off)}
          aria-pressed={!off}
          className="h-12 rounded-2xl bg-raised px-5 text-[15px] font-semibold text-text hover:bg-line"
        >
          {off ? "Show Tiko" : "Hide Tiko"}
        </button>
      </div>
    </section>
  );
}
