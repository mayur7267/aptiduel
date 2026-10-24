import Link from "next/link";
import type { ReactNode } from "react";
import { initials, tierFor } from "@/lib/format";
import { Bolt, Bot, Shield } from "./icons";

export function Logo({ href = "/" }: { href?: string }) {
  return (
    <Link href={href} className="group flex items-center gap-2.5 text-text hover:text-text">
      <span className="sticker flex size-[34px] -rotate-6 items-center justify-center rounded-[10px] bg-lime text-ink transition-transform [--pop:#6f8a14] group-hover:rotate-0">
        <Bolt size={18} strokeWidth={2.6} />
      </span>
      <span className="font-display text-lg font-bold">
        Apti<span className="text-lime">Duel</span>
      </span>
    </Link>
  );
}

// Each name always gets the same colour, so lists are easy to scan.
const AVATAR_TONES = [
  "bg-[#2b3350] text-[#dbe1f0]",
  "bg-[#3a2a3f] text-[#f3c4f0]",
  "bg-[#253a30] text-[#bff0cf]",
  "bg-[#3d2e1f] text-[#ffd2a8]",
  "bg-[#22344a] text-[#b9dcff]",
  "bg-[#3d2530] text-[#ffc2cc]",
  "bg-[#33361c] text-[#e6f5a6]",
];

function avatarTone(name: string) {
  let h = 0;
  for (const ch of name) h = (h * 31 + ch.charCodeAt(0)) | 0;
  return AVATAR_TONES[Math.abs(h) % AVATAR_TONES.length];
}

export function Avatar({ name, size = 44, ring }: { name: string; size?: number; ring?: string }) {
  return (
    <span
      aria-hidden="true"
      className={`flex shrink-0 items-center justify-center rounded-full font-bold ${avatarTone(name)} ${ring ?? ""}`}
      style={{ width: size, height: size, fontSize: Math.round(size * 0.32) }}
    >
      {initials(name)}
    </span>
  );
}

// A player's avatar, or a robot for practice bots.
export function PlayerAvatar({ name, bot, size = 44, ring }: { name: string; bot: boolean; size?: number; ring?: string }) {
  if (!bot) return <Avatar name={name} size={size} ring={ring} />;
  return (
    <span
      aria-hidden="true"
      className={`flex shrink-0 items-center justify-center rounded-full bg-lime-tint text-lime ${ring ?? ""}`}
      style={{ width: size, height: size }}
    >
      <Bot size={Math.round(size * 0.52)} strokeWidth={2} />
    </span>
  );
}

export function BotTag() {
  return (
    <span className="ml-1.5 inline-flex translate-y-[-1px] items-center rounded-md bg-lime-tint px-1.5 py-0.5 align-middle text-[10px] font-bold tracking-wider text-lime">
      BOT
    </span>
  );
}

export function TierBadge({ rating, showRating = false }: { rating: number; showRating?: boolean }) {
  const tier = tierFor(rating);
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full bg-violet-tint px-2.5 py-1 text-[13px] font-semibold text-violet">
      <Shield size={14} strokeWidth={2.2} />
      {tier.name}
      {showRating && <span>· {rating.toLocaleString("en-IN")}</span>}
    </span>
  );
}

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`rounded-[20px] border border-line bg-surface ${className}`}>{children}</div>;
}

export function Spinner({ label = "Loading" }: { label?: string }) {
  return (
    <div role="status" className="flex items-center justify-center gap-3 py-10 text-muted">
      <span className="size-5 animate-spin rounded-full border-2 border-line border-t-lime" />
      <span className="text-sm">{label}…</span>
    </div>
  );
}

export function ErrorNote({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div role="alert" className="flex flex-col items-start gap-3 rounded-2xl border border-red-tint bg-red-tint/40 p-4 text-sm text-red-soft">
      <span>{message}</span>
      {onRetry && (
        <button onClick={onRetry} className="rounded-xl bg-raised px-4 py-2 font-semibold text-text hover:bg-line">
          Try again
        </button>
      )}
    </div>
  );
}
