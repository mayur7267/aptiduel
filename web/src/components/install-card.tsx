"use client";

import { useEffect, useState, useSyncExternalStore } from "react";
import { APP_STORE_URL, isAppleMobile } from "@/lib/app-store";
import { installStore, promptInstall, recentlyDismissed, rememberDismissed, watchInstallPrompt } from "@/lib/install";
import { Close } from "./icons";
import { Mark } from "./ui";

const noChanges = () => () => {};

// After a player's first game on a phone: iPhones are offered the App Store
// app, and Android gets "Add to Home screen" once the browser says the site
// can be installed. Nothing shows on desktops.
export function InstallCard({ ready }: { ready: boolean }) {
  const canInstall = useSyncExternalStore(installStore.subscribe, installStore.get, installStore.serverGet);
  const iphone = useSyncExternalStore(noChanges, isAppleMobile, () => false);
  const [hidden, setHidden] = useState(() => recentlyDismissed());

  useEffect(() => watchInstallPrompt(), []);

  if (!ready || hidden || !(iphone || canInstall)) return null;

  async function install() {
    const accepted = await promptInstall();
    if (!accepted) rememberDismissed();
    setHidden(true);
  }

  function later() {
    rememberDismissed();
    setHidden(true);
  }

  const action = "flex h-10 shrink-0 items-center rounded-xl bg-lime px-4 text-sm font-bold text-ink hover:bg-lime-hover hover:text-ink";
  return (
    <div className="flex items-center gap-3 rounded-2xl border border-line bg-surface p-3.5 lg:hidden">
      <Mark size={40} />
      <div className="min-w-0 flex-1">
        <p className="text-[15px] font-semibold">{iphone ? "Get Apticks for iPhone" : "Add Apticks to your home screen"}</p>
        <p className="text-xs text-muted">{iphone ? "Free on the App Store." : "One tap to your Daily, like an app."}</p>
      </div>
      {iphone ? (
        <a href={APP_STORE_URL} onClick={() => setHidden(true)} className={action}>
          Get
        </a>
      ) : (
        <button onClick={install} className={action}>
          Install
        </button>
      )}
      <button onClick={later} aria-label="Not now" className="-mr-1 flex size-8 shrink-0 items-center justify-center rounded-full text-muted hover:text-text">
        <Close size={16} />
      </button>
    </div>
  );
}
