"use client";

// "Add to Home screen" on Android. Chrome fires `beforeinstallprompt` once,
// early, so a small script in the layout catches it (lib/install-early.ts) and
// this keeps it until the home page wants to offer the install.

type PromptEvent = Event & { prompt: () => Promise<void>; userChoice: Promise<{ outcome: "accepted" | "dismissed" }> };
type Early = Window & { __installPrompt?: PromptEvent };

const DISMISSED_KEY = "apticks-install-dismissed";
const QUIET_DAYS = 14;

let deferred: PromptEvent | null = null;
let started = false;
const listeners = new Set<() => void>();
const emit = () => listeners.forEach((l) => l());

// Called once, on the client.
export function watchInstallPrompt() {
  if (started) return;
  started = true;
  const early = (window as Early).__installPrompt;
  if (early) deferred = early;
  window.addEventListener("beforeinstallprompt", (e) => {
    e.preventDefault();
    deferred = e as PromptEvent;
    emit();
  });
  window.addEventListener("appinstalled", () => {
    deferred = null;
    emit();
  });
  if (deferred) emit();
}

export const installStore = {
  subscribe(l: () => void) {
    listeners.add(l);
    return () => listeners.delete(l);
  },
  get: () => deferred !== null,
  serverGet: () => false,
};

// Shows Chrome's own install dialog. True when they said yes.
export async function promptInstall(): Promise<boolean> {
  const e = deferred;
  if (!e) return false;
  deferred = null;
  emit();
  await e.prompt();
  return (await e.userChoice).outcome === "accepted";
}

// Asked and declined: stay quiet for a couple of weeks.
export function recentlyDismissed(now = Date.now()): boolean {
  try {
    const at = Number(localStorage.getItem(DISMISSED_KEY));
    return at > 0 && now - at < QUIET_DAYS * 86_400_000;
  } catch {
    return false;
  }
}

export function rememberDismissed(now = Date.now()) {
  try {
    localStorage.setItem(DISMISSED_KEY, String(now));
  } catch {
    // Private windows: it will simply ask again next time.
  }
}
