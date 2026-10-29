"use client";

import Link from "next/link";
import { useEffect, useRef, useState, type CSSProperties, type PointerEvent, type ReactNode, type Ref } from "react";
import { account, type Account } from "@/lib/account";
import { api, type DuelSummary, type Me } from "@/lib/api";
import { COMPANIES } from "@/lib/companies";
import { openFeedback } from "@/lib/feedback";
import { batch, signed } from "@/lib/format";
import { ratingHistory, weekChange } from "@/lib/rating-history";
import { Bolt, Flame } from "@/components/icons";
import { Modal } from "@/components/modal";
import { Tiko } from "@/components/tiko";
import { Avatar, ErrorNote, Logo, Spinner, TierBadge } from "@/components/ui";
import { AccountPanel } from "./account-panel";
import { ProfileForm } from "./profile-form";
import { TikoSettings } from "./tiko-settings";

// The profile page: a grid of tiles, each showing something real and
// opening something. Editing, the account and Tiko's settings open in
// dialogs. Matches the iPhone app's Profile tab.

type Sheet = "edit" | "account" | "tiko";

export function ProfileHub() {
  const [me, setMe] = useState<Me | null>(null);
  const [duels, setDuels] = useState<DuelSummary[]>([]);
  const [acct, setAcct] = useState<Account | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  const [sheet, setSheet] = useState<Sheet | null>(null);

  useEffect(() => {
    let active = true;
    Promise.all([api.getMe(), api.myDuels(30).catch(() => []), account.get().catch(() => null)])
      .then(([m, d, a]) => {
        if (!active) return;
        setMe(m);
        setDuels(d);
        setAcct(a);
        setError(null);
      })
      .catch((e: Error) => active && setError(e.message));
    return () => {
      active = false;
    };
  }, [attempt]);

  // Next keeps this page mounted (hidden) after you leave; close any dialog then.
  useEffect(() => () => setSheet(null), []);

  const close = () => setSheet(null);

  return (
    <>
      <div className="mb-4 flex items-center justify-between">
        <span className="lg:hidden">
          <Logo />
        </span>
        <h1 className="font-poster text-[34px] leading-none uppercase lg:text-[40px]">You</h1>
      </div>

      {!me ? (
        error ? (
          <ErrorNote message={error} onRetry={() => setAttempt((n) => n + 1)} />
        ) : (
          <Spinner label="Loading your profile" />
        )
      ) : (
        <div className="grid grid-cols-2 gap-3">
          <PlayerCard me={me} onEdit={() => setSheet("edit")} />
          <TiltTile href="/leaderboard" className="row-span-2 min-h-[312px] bg-violet" delay={60} label="Insights: your rating">
            <Insights me={me} duels={duels} />
          </TiltTile>
          <TiltTile href="/daily" className="min-h-[150px] bg-orange" delay={100} label={`Streak: ${me.streak} days`}>
            <Streak me={me} />
          </TiltTile>
          <TiltTile onClick={() => setSheet("tiko")} className="min-h-[150px] bg-[#5ce1e6]" delay={140} label="Tiko settings">
            <TikoTile />
          </TiltTile>
          <div className="col-span-2 grid grid-cols-[1fr_0.62fr] gap-3">
            <TiltTile href="/play" className="min-h-[150px] bg-lime" delay={180} label="Compete: find a Quick Match">
              <Compete />
            </TiltTile>
            <Practice />
          </div>
          <Help />
          <TiltTile
            onClick={() => setSheet("account")}
            className={`min-h-[150px] border-[1.5px] bg-surface ${acct?.guest === false ? "border-line" : "border-lime/50"}`}
            delay={300}
            label="Account"
          >
            <AccountTile acct={acct} />
          </TiltTile>
        </div>
      )}

      <Modal open={sheet === "edit"} onClose={close} title="Your profile">
        <ProfileForm
          onSaved={() => {
            close();
            setAttempt((n) => n + 1);
          }}
        />
      </Modal>
      <Modal open={sheet === "account"} onClose={close} title="Account">
        <AccountPanel bare />
      </Modal>
      <Modal open={sheet === "tiko"} onClose={close} title="Tiko">
        <TikoSettings bare />
      </Modal>
    </>
  );
}

// A tile that leans towards the pointer and gives under a press.
function TiltTile({
  href,
  onClick,
  className,
  delay,
  label,
  children,
}: {
  href?: string;
  onClick?: () => void;
  className: string;
  delay: number;
  label: string;
  children: ReactNode;
}) {
  const ref = useRef<HTMLElement>(null);

  function lean(e: PointerEvent<HTMLElement>) {
    if (e.pointerType !== "mouse" || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const el = ref.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    const x = (e.clientX - r.left) / r.width - 0.5;
    const y = (e.clientY - r.top) / r.height - 0.5;
    el.style.transform = `perspective(700px) rotateX(${(-y * 6).toFixed(2)}deg) rotateY(${(x * 6).toFixed(2)}deg)`;
  }

  function settle() {
    if (ref.current) ref.current.style.transform = "";
  }

  const cls = `group relative block overflow-hidden rounded-[26px] text-left text-ink transition-transform duration-200 ease-out active:scale-[0.97] motion-safe:animate-rise ${className}`;
  const style: CSSProperties = { animationDelay: `${delay}ms` };
  if (href) {
    return (
      <Link
        ref={ref as Ref<HTMLAnchorElement>}
        href={href}
        aria-label={label}
        onPointerMove={lean}
        onPointerLeave={settle}
        className={`${cls} hover:text-ink`}
        style={style}
      >
        {children}
      </Link>
    );
  }
  return (
    <button
      ref={ref as Ref<HTMLButtonElement>}
      onClick={onClick}
      aria-label={label}
      onPointerMove={lean}
      onPointerLeave={settle}
      className={cls}
      style={style}
    >
      {children}
    </button>
  );
}

function Poster({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <span className={`block truncate font-poster leading-[0.95] uppercase ${className}`}>{children}</span>;
}

// You: a drifting stripe banner with Tiko standing on it, your avatar in
// your tier's ring, and your numbers.
function PlayerCard({ me, onEdit }: { me: Me; onEdit: () => void }) {
  const guestName = /^Player \d{4}$/.test(me.name);
  const winRate = me.games_played > 0 ? `${Math.round((me.wins / me.games_played) * 100)}%` : "—";
  const sub = [me.college, batch(me.grad_year)].filter(Boolean).join(" · ") || "Add your college to join its leaderboard";
  return (
    <section className="relative col-span-2 overflow-hidden rounded-[28px] border-[1.5px] border-line bg-surface motion-safe:animate-rise">
      <div
        aria-hidden="true"
        className="stripes-drift h-[92px] bg-lime"
        style={{ backgroundImage: "repeating-linear-gradient(135deg, rgb(255 255 255 / 0.28) 0 11px, transparent 11px 34px)" }}
      />
      <div className="absolute top-[30px] right-[78px]">
        <Tiko mood="wave" size={62} />
      </div>
      <div className="flex items-end justify-between px-5">
        <span className="-mt-[42px] rounded-full bg-surface p-1 ring-[3px] ring-violet">
          <Avatar name={me.name} size={84} />
        </span>
        <button
          onClick={onEdit}
          aria-label="Edit profile"
          className="-mt-6 flex size-12 items-center justify-center rounded-full bg-lime text-ink transition hover:bg-lime-hover active:scale-95"
        >
          <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round">
            <path d="M12 20h9" />
            <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z" />
          </svg>
        </button>
      </div>
      <button onClick={onEdit} className="block w-full px-5 pt-3 text-left">
        <span className={`block truncate font-display text-[22px] font-bold ${guestName ? "text-muted" : "text-text"}`}>
          {guestName ? "Add your name" : me.name}
        </span>
        <span className="block truncate text-sm text-muted">{sub}</span>
        <span className="mt-2 inline-block">
          <TierBadge rating={me.rating} showRating />
        </span>
      </button>
      <dl className="m-3.5 grid grid-cols-4 divide-x divide-line rounded-2xl bg-raised py-3 text-center">
        {[
          [String(me.games_played), "Duels"],
          [String(me.wins), "Wins"],
          [winRate, "Win rate"],
          [String(me.streak_best), "Best streak"],
        ].map(([value, label]) => (
          <div key={label} className="flex flex-col-reverse gap-0.5">
            <dt className="text-[11px] font-semibold text-muted">{label}</dt>
            <dd className="font-mono text-[17px] font-bold">{value}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}

// Rating over recent duels: a zigzag that draws itself, with a glowing
// dot on today.
function Insights({ me, duels }: { me: Me; duels: DuelSummary[] }) {
  const history = ratingHistory(duels, me.rating);
  const week = weekChange(duels);
  const shown = history.length >= 2 ? history : [0, 3, 2, 5, 4, 7, 6, 9];
  const lo = Math.min(...shown);
  const hi = Math.max(Math.max(...shown), lo + 1);
  const pts = shown.map((v, i) => [(i / (shown.length - 1)) * 94, 6 + 48 * (1 - (v - lo) / (hi - lo))] as const);
  const line = pts.map(([x, y], i) => `${i ? "L" : "M"}${x.toFixed(2)} ${y.toFixed(2)}`).join(" ");
  const last = pts[pts.length - 1];
  return (
    <div className="flex h-full flex-col p-[18px]">
      <Poster className="text-[clamp(30px,10vw,42px)]">Insights</Poster>
      <span
        className={`mt-2 inline-flex items-center gap-1.5 self-start rounded-full bg-ink px-3 py-1.5 text-[13px] font-black ${week >= 0 ? "text-lime" : "text-red-soft"}`}
      >
        {week >= 0 ? "▲" : "▼"} {history.length >= 2 ? `${signed(week)} this week` : "Rating"}
      </span>
      <div className={`relative mt-3 flex-1 ${history.length >= 2 ? "" : "opacity-45"}`}>
        <svg aria-hidden="true" viewBox="0 0 100 60" preserveAspectRatio="none" className="absolute inset-0 h-full w-full overflow-visible">
          <path className="chart-fill" d={`${line} L${last[0]} 60 L0 60 Z`} fill="rgb(11 14 23 / 0.16)" />
          <path
            className="chart-draw"
            pathLength={1}
            d={line}
            fill="none"
            stroke="#0b0e17"
            strokeWidth={3.2}
            strokeLinejoin="round"
            strokeLinecap="round"
            vectorEffect="non-scaling-stroke"
          />
        </svg>
        <span
          aria-hidden="true"
          className="absolute size-[15px] -translate-x-1/2 -translate-y-1/2 rounded-full border-[3px] border-ink bg-lime motion-safe:animate-pop"
          style={{ left: `${last[0]}%`, top: `${(last[1] / 60) * 100}%`, animationDelay: "1.3s" }}
        >
          <span className="absolute -inset-1.5 rounded-full bg-lime/50 motion-safe:animate-ping" />
        </span>
      </div>
      <span className="mt-3 font-mono text-[26px] leading-none font-bold">{me.rating.toLocaleString("en-IN")}</span>
      <span className="mt-1 text-xs font-semibold text-ink/60">
        {history.length > 2
          ? `Last ${history.length - 1} rated duels`
          : history.length === 2
            ? "Your last rated duel"
            : "Play a duel to start your chart"}
      </span>
    </div>
  );
}

// The streak, burning.
function Streak({ me }: { me: Me }) {
  return (
    <div className="flex h-full flex-col p-4">
      <Poster className="text-[32px]">Streak</Poster>
      <span className="mt-auto flex items-end gap-1.5">
        <Flame size={30} strokeWidth={2.4} className="flame-flicker mb-1 fill-[#ffe066]" />
        <span className="font-poster text-[44px] leading-none">{me.streak}</span>
        <span className="mb-1 text-[13px] font-black text-ink/70">{me.streak === 1 ? "day" : "days"}</span>
      </span>
      <span className="mt-2 flex gap-1" aria-hidden="true">
        {me.daily_week.map((done, i) => (
          <span
            key={i}
            className={`size-[13px] rounded-full ${done ? "bg-ink" : "bg-ink/20"} ${i === me.today_idx ? "ring-2 ring-ink ring-offset-1 ring-offset-orange" : ""}`}
          />
        ))}
      </span>
    </div>
  );
}

function TikoTile() {
  return (
    <div className="flex h-full flex-col p-4">
      <Poster className="text-[32px]">Tiko</Poster>
      <span className="mt-0.5 text-xs leading-tight font-black text-ink/65">
        Tour, intro
        <br />& more
      </span>
      <span className="absolute right-2.5 -bottom-1.5">
        <Tiko mood="happy" size={72} interactive={false} />
      </span>
    </div>
  );
}

// Every way to play, scrolling by.
function Compete() {
  const items: [string, string][] = [
    ["Quick Match", "text-lime"],
    ["Daily Challenge", "text-orange"],
    ["Challenge a friend", "text-violet"],
    ["Company practice", "text-[#5ce1e6]"],
  ];
  const strip = (hidden: boolean) => (
    <span aria-hidden={hidden || undefined} className="flex shrink-0 items-center gap-3.5 pr-3.5">
      {items.map(([text, tone]) => (
        <span key={text} className="flex items-center gap-3.5">
          <span className={`font-poster text-[24px] whitespace-nowrap uppercase ${tone}`}>{text}</span>
          <span className="size-[7px] rounded-full bg-text/85" />
        </span>
      ))}
    </span>
  );
  return (
    <div className="flex h-full flex-col">
      <Bolt size={24} strokeWidth={2.6} className="absolute top-3.5 right-3.5 rotate-12 fill-ink" />
      <Poster className="px-[18px] pt-3.5 pr-11 text-[clamp(32px,10vw,44px)]">Compete</Poster>
      <span className="mt-auto mb-3.5 flex overflow-hidden bg-ink py-2">
        <span className="marquee-track flex w-max">
          {strip(false)}
          {strip(true)}
        </span>
      </span>
    </div>
  );
}

// Company practice: the four test patterns, each a shortcut.
function Practice() {
  const tones = ["bg-lime", "bg-violet", "bg-orange", "bg-[#5ce1e6]"];
  const short = ["TCS", "INF", "ACN", "WIP"];
  return (
    <div
      className="flex min-h-[150px] flex-col rounded-[26px] border-[1.5px] border-line bg-raised p-4 motion-safe:animate-rise"
      style={{ animationDelay: "220ms" }}
    >
      <Poster className="text-[30px] text-text">Practice</Poster>
      <span className="text-xs font-black text-muted">By company</span>
      <span className="mt-auto flex -space-x-2.5">
        {COMPANIES.map((c, i) => (
          <Link
            key={c.slug}
            href={`/play/${c.slug}`}
            title={`${c.name} practice`}
            aria-label={`${c.name} practice`}
            className={`badge-bob flex size-9 items-center justify-center rounded-[11px] border-[2.5px] border-ink text-[10px] font-black text-ink transition hover:z-10 hover:scale-110 hover:text-ink ${tones[i]}`}
            style={{ rotate: `${(i - 1.5) * 6}deg`, animationDelay: `${i * 0.3}s`, zIndex: 4 - i }}
          >
            {short[i]}
          </Link>
        ))}
      </span>
    </div>
  );
}

// Report a problem or suggest an idea.
function Help() {
  const pill = "flex h-9 items-center justify-center gap-2 rounded-full bg-raised text-[13px] font-bold text-text transition hover:bg-line active:scale-[0.97]";
  return (
    <div
      className="flex min-h-[150px] flex-col gap-2 rounded-[26px] border-[1.5px] border-line bg-surface p-3.5 motion-safe:animate-rise"
      style={{ animationDelay: "260ms" }}
    >
      <Poster className="text-[30px] text-text">Help us</Poster>
      <button onClick={() => openFeedback("bug", { from: "profile" })} className={`mt-auto ${pill}`}>
        🐞 Report a problem
      </button>
      <button onClick={() => openFeedback("idea", { from: "profile" })} className={pill}>
        💡 Suggest an idea
      </button>
    </div>
  );
}

// Whether this browser's progress is saved, and where.
function AccountTile({ acct }: { acct: Account | null }) {
  const guest = acct?.guest ?? true;
  return (
    <div className="flex h-full flex-col p-4 text-text">
      <Poster className="text-[30px]">Account</Poster>
      <span className="mt-auto text-2xl" aria-hidden="true">
        {guest ? "🔓" : "🛡️"}
      </span>
      <span className={`mt-1 truncate text-[13px] font-bold ${guest ? "text-lime" : "text-soft"}`}>
        {guest ? "Save your progress" : acct?.email ?? "Saved"}
      </span>
    </div>
  );
}
