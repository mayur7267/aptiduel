"use client";

import { useEffect, useState, useSyncExternalStore } from "react";
import { installStore, promptInstall, recentlyDismissed, rememberDismissed, watchInstallPrompt } from "@/lib/install";
import { Close } from "./icons";
import { Mark } from "./ui";

// Offers "Add to Home screen" on phones, after a player's first game, once
// the browser says the site can be installed. Nothing shows anywhere else:
// iPhones have the app, and desktops don't get the prompt.
export function InstallCard({ ready }: { ready: boolean }) {
  const canInstall = useSyncExternalStore(installStore.subscribe, installStore.get, installStore.serverGet);
  const [hidden, setHidden] = useState(() => recentlyDismissed());

  useEffect(() => watchInstallPrompt(), []);

  if (!ready || !canInstall || hidden) return null;

  async function install() {
    const accepted = await promptInstall();
    if (!accepted) rememberDismissed();
    setHidden(true);
  }

  function later() {
    rememberDismissed();
    setHidden(true);
  }

  return (
    <div className="flex items-center gap-3 rounded-2xl border border-line bg-surface p-3.5 lg:hidden">
      <Mark size={40} />
      <div className="min-w-0 flex-1">
        <p className="text-[15px] font-semibold">Add Apticks to your home screen</p>
        <p className="text-xs text-muted">One tap to your Daily, like an app.</p>
      </div>
      <button onClick={install} className="h-10 shrink-0 rounded-xl bg-lime px-4 text-sm font-bold text-ink hover:bg-lime-hover">
        Install
      </button>
      <button onClick={later} aria-label="Not now" className="-mr-1 flex size-8 shrink-0 items-center justify-center rounded-full text-muted hover:text-text">
        <Close size={16} />
      </button>
    </div>
  );
}
