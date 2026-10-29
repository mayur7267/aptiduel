"use client";

import Link from "next/link";
import { useEffect, useRef, useState, type PointerEvent, type ReactNode } from "react";
import { account, type Account } from "@/lib/account";
import { api, type DuelSummary, type Me } from "@/lib/api";
import { COMPANIES } from "@/lib/companies";
import { openFeedback } from "@/lib/feedback";
import { signed, tierFor, TIERS } from "@/lib/format";
import { ratingHistory, weekChange } from "@/lib/rating-history";
import { ChevronRight } from "@/components/icons";
import { Modal } from "@/components/modal";
import { Tiko } from "@/components/tiko";
import { Avatar, ErrorNote, Logo, Mark, Spinner } from "@/components/ui";
import { AccountPanel } from "./account-panel";
import { ProfileForm } from "./profile-form";
import { TikoSettings } from "./tiko-settings";

// The profile page, as a page from a placement student's folder: your
// player card swinging on a lanyard, your rating on graph paper, a
// report card, a sticker book and sticky notes. Matches the iPhone app.

type Sheet = "edit" | "account" | "tiko" | "practice";

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
  const saved = acct?.guest === false;

  return (
    <>
      <div className="mb-2 flex items-center justify-between gap-3">
        <span className="lg:hidden">
          <Logo />
        </span>
        <h1 className="sr-only">Your profile</h1>
        <RedPen className="ml-auto text-[17px]">tap or drag your card</RedPen>
      </div>

      {!me ? (
        error ? (
          <ErrorNote message={error} onRetry={() => setAttempt((n) => n + 1)} />
        ) : (
          <Spinner label="Loading your profile" />
        )
      ) : (
        <div className="flex flex-col gap-4">
          <IdBadge me={me} saved={saved} onEdit={() => setSheet("edit")} />
          {/* Phones: progress, stickers, report card. Wider: stickers across the top, then the two side by side. */}
          <div className="grid gap-4 md:grid-cols-2">
            <Progress me={me} duels={duels} className="md:order-2" />
            <StickerBook me={me} saved={saved} className="md:order-1 md:col-span-2" />
            <ReportCard me={me} className="md:order-3" />
          </div>
          <div className="grid grid-cols-2 gap-4 pt-2">
            <StickyNote
              tone="bg-lime"
              tilt={-3}
              title="Found a bug?"
              line="Tell us what broke"
              onClick={() => openFeedback("bug", { from: "profile" })}
            />
            <StickyNote
              tone="bg-violet"
              tilt={2.5}
              title="Got an idea?"
              line="We read every one"
              onClick={() => openFeedback("idea", { from: "profile" })}
            />
          </div>
          <div className="divide-y divide-line overflow-hidden rounded-[20px] border border-line bg-surface">
            <Row icon="☺" title="Tiko & the tour" detail="Replay the tour, show or hide Tiko" onClick={() => setSheet("tiko")} />
            <Row
              icon={saved ? "✓" : "🔓"}
              accent={!saved}
              title={saved ? "Account" : "Save your progress"}
              detail={saved ? (acct?.email ?? "Saved") : "Keep your rating on any device"}
              onClick={() => setSheet("account")}
            />
            <Row icon="🏢" title="Practise for a company" detail="TCS NQT, Infosys, Accenture, Wipro" onClick={() => setSheet("practice")} />
          </div>
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
      <Modal open={sheet === "practice"} onClose={close} title="Practise for…">
        <p className="-mt-2 text-sm text-muted">A rated duel using only the topics on that company&apos;s aptitude test.</p>
        <div className="flex flex-col gap-2.5">
          {COMPANIES.map((c) => (
            <Link
              key={c.slug}
              href={`/play/${c.slug}`}
              onClick={close}
              className="flex items-center justify-between rounded-2xl border border-line bg-raised px-4 py-3.5 text-text hover:border-lime/60 hover:text-text"
            >
              <span>
                <span className="block font-bold">{c.name}</span>
                <span className="block text-xs text-muted">{c.blurb}</span>
              </span>
              <ChevronRight size={18} className="text-muted" />
            </Link>
          ))}
        </div>
      </Modal>
    </>
  );
}

function RedPen({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <span className={`inline-block -rotate-2 font-hand font-bold text-red-soft ${className}`}>{children}</span>;
}

function Heading({ children, aside }: { children: ReactNode; aside?: ReactNode }) {
  return (
    <div className="flex items-baseline justify-between">
      <h2 className="font-mono text-xs font-bold tracking-[0.2em] text-muted uppercase">{children}</h2>
      {aside}
    </div>
  );
}

// Your player card on a lanyard. It swings as a damped pendulum: a tap
// flicks it, a drag pushes it, scrolling jostles it and a light breeze
// keeps it moving. On phones it also hangs towards real "down" as you
// tilt (iPhones ask permission on the first tap). The holographic seal
// and a sheen move with it.
function IdBadge({ me, saved, onEdit }: { me: Me; saved: boolean; onEdit: () => void }) {
  const card = useRef<HTMLDivElement>(null);
  const physics = useRef({ theta: 0.3, omega: 0, tilt: 0, held: null as number | null, heldV: 0 });
  const press = useRef<{ x: number; t: number; moved: boolean } | null>(null);
  const listenTilt = useRef<(() => void) | null>(null);
  const [tiltAsk, setTiltAsk] = useState(false); // iPhone: tilt needs a tap to ask first

  useEffect(() => {
    const el = card.current;
    if (!el || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const p = physics.current;
    let frame = 0;
    let last = performance.now();
    const tick = (now: number) => {
      const dt = Math.min(1 / 30, (now - last) / 1000);
      last = now;
      // Where it hangs: towards the tilt, nudged by a slow breeze.
      const t = now / 1000;
      const rest = p.tilt + 0.04 * Math.sin(t * 0.9) + 0.015 * Math.sin(t * 2.3 + 1);
      if (p.held === null) {
        for (let i = 0; i < 4; i++) {
          p.omega += (-16 * Math.sin(p.theta - rest) - 0.9 * p.omega) * (dt / 4);
          p.theta += p.omega * (dt / 4);
        }
      } else {
        p.theta += (p.held - p.theta) * 0.5;
      }
      el.style.setProperty("--swing", String(p.theta));
      el.style.rotate = `${p.theta}rad`;
      frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);

    // Scrolling the page jostles the card.
    let lastY = window.scrollY;
    const scroll = () => {
      const dy = window.scrollY - lastY;
      lastY = window.scrollY;
      p.omega += Math.max(-0.5, Math.min(0.5, dy * 0.006));
    };
    window.addEventListener("scroll", scroll, { passive: true });

    const tilt = (e: DeviceOrientationEvent) => {
      if (e.gamma !== null) p.tilt = Math.max(-0.4, Math.min(0.4, -(e.gamma / 90) * 0.6));
    };
    const D = window.DeviceOrientationEvent as unknown as { requestPermission?: () => Promise<string> } | undefined;
    let listening = false;
    const start = () => {
      if (listening) return;
      listening = true;
      window.addEventListener("deviceorientation", tilt);
    };
    if (D && typeof D.requestPermission !== "function") {
      start(); // Android and desktop: no permission needed.
    } else if (D?.requestPermission && "ontouchstart" in window) {
      // iPhone and iPad: ask on the first tap of the card.
      listenTilt.current = () => {
        listenTilt.current = null;
        D.requestPermission!().then((r) => r === "granted" && start(), () => {});
      };
      const ask = window.setTimeout(() => setTiltAsk(true), 0);
      return () => {
        window.clearTimeout(ask);
        cancelAnimationFrame(frame);
        window.removeEventListener("scroll", scroll);
        window.removeEventListener("deviceorientation", tilt);
      };
    }
    return () => {
      cancelAnimationFrame(frame);
      window.removeEventListener("scroll", scroll);
      window.removeEventListener("deviceorientation", tilt);
    };
  }, []);

  function down(e: PointerEvent<HTMLDivElement>) {
    press.current = { x: e.clientX, t: performance.now(), moved: false };
    e.currentTarget.setPointerCapture(e.pointerId);
  }

  function move(e: PointerEvent<HTMLDivElement>) {
    const pr = press.current;
    if (!pr) return;
    const dx = e.clientX - pr.x;
    if (Math.abs(dx) > 6) pr.moved = true;
    if (!pr.moved) return;
    const p = physics.current;
    const angle = Math.max(-0.9, Math.min(0.9, -dx / 220));
    const now = performance.now();
    if (p.held !== null) p.heldV = (angle - p.held) / Math.max(0.016, (now - pr.t) / 1000);
    pr.t = now;
    p.held = angle;
  }

  // A tap flicks the card (and, on iPhone, asks to use tilt once).
  function up() {
    const pr = press.current;
    press.current = null;
    const p = physics.current;
    if (pr?.moved) {
      p.omega = Math.max(-6, Math.min(6, p.heldV));
      p.held = null;
      return;
    }
    p.omega += (p.theta >= 0 ? 1 : -1) * 3;
    navigator.vibrate?.(10);
    if (listenTilt.current) {
      listenTilt.current();
      setTiltAsk(false);
    }
  }

  const tier = tierFor(me.rating);
  const guest = /^Player \d{4}$/.test(me.name);
  const number = me.id.replace(/-/g, "").slice(0, 8).toUpperCase();
  return (
    <section aria-label="Your player card" className="relative mt-7 h-[352px] select-none lg:mt-2">
      {/* The lanyard. */}
      <svg aria-hidden="true" className="absolute inset-x-0 -top-6 mx-auto h-[80px] w-[220px] overflow-visible" viewBox="0 0 220 80">
        {[-1, 1].map((s) => (
          <g key={s}>
            <line x1={110 + s * 72} y1={0} x2={110 + s * 7} y2={68} stroke="#9fc41f" strokeWidth={11} strokeLinecap="round" />
            <line x1={110 + s * 72} y1={0} x2={110 + s * 7} y2={68} stroke="rgb(11 14 23 / 0.35)" strokeWidth={1.5} strokeDasharray="5 5" />
          </g>
        ))}
        <circle cx={110} cy={70} r={9} fill="#c3c9d6" stroke="rgb(11 14 23 / 0.5)" strokeWidth={2} />
      </svg>
      <div className="absolute top-[54px] left-1/2 w-[min(320px,calc(100%-40px))] -translate-x-1/2">
        <div
          ref={card}
          role="button"
          tabIndex={0}
          aria-label={`Player card: ${me.name}, ${tier.name}, rating ${me.rating}. Tap to swing it.`}
          onKeyDown={(e) => {
            if (e.key === "Enter" || e.key === " ") physics.current.omega += 3;
          }}
          onPointerDown={down}
          onPointerMove={move}
          onPointerUp={up}
          onPointerCancel={() => (press.current = null)}
          className="relative origin-top cursor-grab touch-pan-y active:cursor-grabbing"
          style={{ rotate: "0.3rad" }}
        >
          {/* Tiko rides on top of the card. */}
          <span className="absolute -top-[52px] right-6">
            <Tiko mood="wave" size={54} interactive={false} />
          </span>
          <div className="relative h-[238px] overflow-hidden rounded-2xl bg-text text-ink shadow-[0_14px_36px_rgb(0_0_0/0.55)]">
            <div className="flex h-9 items-center gap-2 bg-ink px-3.5 text-lime">
              <Mark size={18} />
              <span className="font-mono text-xs font-bold tracking-[0.2em]">APTICKS</span>
              <span className="ml-auto font-mono text-[10px] font-semibold tracking-[0.14em] opacity-70">PLAYER CARD</span>
            </div>
            <div className="flex gap-3.5 px-3.5 pt-3.5">
              <span className="relative flex h-[98px] w-20 shrink-0 items-center justify-center rounded-[10px] border border-ink/15 bg-raised">
                <Avatar name={me.name} size={64} />
                <span className="absolute bottom-1 font-mono text-[7px] font-bold tracking-[0.15em] text-muted">PHOTO</span>
              </span>
              <dl className="flex min-w-0 flex-col gap-1.5">
                <Field label="Name" value={guest ? "—" : me.name} />
                <Field label="College" value={me.college ?? "—"} />
                <span className="flex gap-5">
                  <Field label="Batch" value={me.grad_year ? `’${String(me.grad_year).slice(2)}` : "—"} />
                  <Field label="Tier" value={tier.name} />
                </span>
                <Field label="Rating" value={me.rating.toLocaleString("en-IN")} big />
              </dl>
            </div>
            <div className="absolute inset-x-3.5 bottom-3 flex items-end gap-2">
              <Barcode seed={me.id} />
              <span className="font-mono text-[10px] font-semibold text-ink/60">No. {number}</span>
              {/* The holographic seal: its rainbow turns with the swing. */}
              <span
                aria-hidden="true"
                className="ml-auto flex size-10 items-center justify-center rounded-full border-[1.5px] border-white/80"
                style={{
                  background:
                    "radial-gradient(circle at 35% 30%, rgb(255 255 255 / 0.7), transparent 55%), conic-gradient(from calc(var(--swing, 0) * 3rad), #c8f135, #5ce1e6, #a594ff, #ff8f9b, #ff8a4c, #c8f135)",
                }}
              >
                <Mark size={22} />
              </span>
            </div>
            {/* A sheen sliding across the laminate. */}
            <span
              aria-hidden="true"
              className="pointer-events-none absolute inset-y-0 left-1/3 w-2/5 rotate-[20deg] bg-gradient-to-r from-transparent via-white/45 to-transparent mix-blend-soft-light"
              style={{ translate: "calc(var(--swing, 0) * 420px) 0" }}
            />
            <span
              className={`absolute top-[58px] right-3 rounded-md border-[2.5px] px-2 py-0.5 font-display text-[13px] font-black tracking-[0.16em] opacity-85 outline outline-1 outline-offset-2 motion-safe:animate-stamp ${
                saved ? "border-violet-strong text-violet-strong outline-violet-strong/70" : "border-red text-red outline-red/70"
              }`}
              style={{ ["--tilt" as string]: "-14deg", animationDelay: "0.6s" }}
            >
              {saved ? "VERIFIED" : "GUEST"}
            </span>
          </div>
          {/* The metal clip. */}
          <span
            aria-hidden="true"
            className="absolute -top-2.5 left-1/2 flex h-[22px] w-[46px] -translate-x-1/2 items-center justify-center rounded-[5px] border border-ink/35 bg-gradient-to-b from-[#e8ecf3] via-[#8b93a7] to-[#d5dae4]"
          >
            <span className="h-[5px] w-6 rounded-full bg-ink/55" />
          </span>
        </div>
      </div>
      <div className="absolute inset-x-0 bottom-0 flex items-center justify-center gap-3">
        <button
          onClick={onEdit}
          className="flex h-9 items-center gap-1.5 rounded-full border border-line bg-surface px-4 text-[13px] font-bold text-text hover:bg-raised active:scale-95"
        >
          ✎ Edit profile
        </button>
        {tiltAsk && <RedPen className="text-base">tap the card to turn on tilt</RedPen>}
      </div>
    </section>
  );
}

function Field({ label, value, big = false }: { label: string; value: string; big?: boolean }) {
  return (
    <span className="flex min-w-0 flex-col">
      <dt className="font-mono text-[8px] font-bold tracking-[0.16em] text-ink/45 uppercase">{label}</dt>
      <dd className={`truncate ${big ? "font-mono text-xl font-bold" : "text-sm font-bold"}`}>{value}</dd>
    </span>
  );
}

// Bars from the player id, like the code on a hall ticket.
function Barcode({ seed }: { seed: string }) {
  const bars: { x: number; w: number }[] = [];
  let h = 2166136261;
  let x = 0;
  for (let i = 0; x < 118; i++) {
    h = Math.imul(h ^ seed.charCodeAt(i % seed.length), 16777619) >>> 0;
    const w = 1 + (h % 3);
    if (h % 5 !== 0) bars.push({ x, w });
    x += w + 1 + ((h >>> 7) % 2);
  }
  return (
    <svg aria-hidden="true" width="120" height="26" viewBox="0 0 120 26">
      {bars.map((b, i) => (
        <rect key={i} x={b.x} y={0} width={b.w} height={26} fill="#0b0e17" />
      ))}
    </svg>
  );
}

// Your rating on graph paper: a pencil line, dashed tier lines (your next
// tier in lime), and today's point circled in red pen.
function Progress({ me, duels, className = "" }: { me: Me; duels: DuelSummary[]; className?: string }) {
  const history = ratingHistory(duels, me.rating);
  const week = weekChange(duels);
  const tier = tierFor(me.rating);
  const has = history.length >= 2;
  const series = has ? history : [me.rating, me.rating];
  const W = 320;
  const H = 170;
  let lo = Math.min(...series) - 40;
  let hi = Math.max(Math.max(...series), tier.next?.min ?? me.rating) + 30;
  if (hi - lo < 120) hi = lo + 120;
  if (!has) lo = me.rating - 80;
  const y = (v: number) => 12 + (H - 22) * (1 - (v - lo) / (hi - lo));
  const pts = series.map((v, i) => [8 + ((W - 34) * i) / Math.max(1, series.length - 1), y(v) + (((i * 37) % 7) - 3) * 0.6] as const);
  const shown = has ? pts : pts.slice(0, 1);
  const line = shown.map(([px, py], i) => `${i ? "L" : "M"}${px.toFixed(1)} ${py.toFixed(1)}`).join(" ");
  const [cx, cy] = shown[shown.length - 1];
  const loop = Array.from({ length: 41 }, (_, i) => {
    const t = (i / 40) * 2.15 * Math.PI - 0.6;
    const r = 15 + 2.5 * Math.sin(t * 1.7);
    return `${i ? "L" : "M"}${(cx + Math.cos(t) * r * 1.25).toFixed(1)} ${(cy + Math.sin(t) * r).toFixed(1)}`;
  }).join(" ");
  const tierLines = TIERS.filter((t) => t.min > lo && t.min < hi);
  return (
    <section className={`flex flex-col gap-2.5 rounded-[20px] border border-line bg-surface p-4 ${className}`}>
      <Heading aside={<span className="font-mono text-[22px] font-bold">{me.rating.toLocaleString("en-IN")}</span>}>Progress</Heading>
      <div className="relative">
        <svg viewBox={`0 0 ${W} ${H}`} className="block h-auto w-full overflow-visible" role="img" aria-label={`Rating ${me.rating}`}>
          <defs>
            <pattern id="graph-paper" width="14" height="14" patternUnits="userSpaceOnUse">
              <path d="M14 0H0V14" fill="none" stroke="rgb(200 241 53 / 0.08)" strokeWidth="0.6" />
            </pattern>
          </defs>
          <rect width={W} height={H} fill="url(#graph-paper)" />
          {tierLines.map((t) => {
            const next = t.name === tier.next?.name;
            return (
              <g key={t.name}>
                <line
                  x1={0}
                  x2={W}
                  y1={y(t.min)}
                  y2={y(t.min)}
                  stroke={next ? "rgb(200 241 53 / 0.7)" : "#3a4256"}
                  strokeWidth={next ? 1.5 : 1}
                  strokeDasharray="5 4"
                />
                <text x={W - 2} y={y(t.min) - 5} textAnchor="end" className={`font-mono text-[9px] font-bold ${next ? "fill-lime" : "fill-faint"}`}>
                  {t.name.toUpperCase()} {t.min.toLocaleString("en-IN")}
                </text>
              </g>
            );
          })}
          <path className="pencil-draw" pathLength={1} d={line} fill="none" stroke="#f2f4f8" strokeWidth={2.6} strokeLinecap="round" strokeLinejoin="round" />
          {shown.map(([px, py], i) => (
            <circle key={i} cx={px} cy={py} r={2.5} fill="#f2f4f8" />
          ))}
          <path className="pen-loop" pathLength={1} d={loop} fill="none" stroke="#ff8f9b" strokeWidth={2.2} strokeLinecap="round" />
        </svg>
        <span
          className="pen-note absolute font-hand text-lg font-bold whitespace-nowrap text-red-soft"
          style={{ left: `${Math.max(2, ((cx - 130) / W) * 100)}%`, top: `${Math.max(0, ((cy - 44) / H) * 100)}%`, rotate: "-3deg" }}
        >
          {has ? `${signed(week)} this week!` : "your first duel goes here"}
        </span>
      </div>
      {tier.next && (
        <p className="text-[13px] font-semibold text-muted">
          {tier.toNext} to go for {tier.next.name}
        </p>
      )}
    </section>
  );
}

// Your stats as a mark sheet, the week as OMR bubbles, and Tiko's remark.
function ReportCard({ me, className = "" }: { me: Me; className?: string }) {
  const winRate = me.games_played > 0 ? Math.round((me.wins / me.games_played) * 100) : null;
  const remark =
    me.games_played === 0
      ? "Yet to appear. All the best!"
      : winRate !== null && winRate >= 60
        ? "Outstanding! Keep it up."
        : me.streak >= 3
          ? "Great streak. Don't break it!"
          : winRate !== null && winRate >= 40
            ? "Good work. Practise daily."
            : "Needs practice. You've got this!";
  const rows: [string, string][] = [
    ["Duels played", String(me.games_played)],
    ["Wins", String(me.wins)],
    ["Win rate", winRate === null ? "—" : `${winRate}%`],
    ["Best streak", `${me.streak_best} ${me.streak_best === 1 ? "day" : "days"}`],
  ];
  return (
    <section className={`flex flex-col gap-3 rounded-[20px] border border-line bg-surface p-4 ${className}`}>
      <Heading aside={<span className="font-mono text-[10px] font-semibold tracking-[0.14em] text-faint">SEASON 1</span>}>Report card</Heading>
      <dl className="flex flex-col gap-2">
        {rows.map(([label, value]) => (
          <div key={label} className="flex items-baseline gap-1.5">
            <dt className="text-sm font-semibold text-soft">{label}</dt>
            <span aria-hidden="true" className="flex-1 border-b-2 border-dotted border-line-strong" />
            <dd className="font-mono text-[15px] font-bold">{value}</dd>
          </div>
        ))}
      </dl>
      <div className="h-px bg-line" />
      <div className="flex items-center justify-between">
        <span className="font-mono text-[10px] font-bold tracking-[0.16em] text-faint">ATTENDANCE</span>
        <span className="text-xs font-bold text-orange">🔥 {me.streak}-day streak</span>
      </div>
      <ol className="grid grid-cols-7" aria-label="Daily challenges this week">
        {["M", "T", "W", "T", "F", "S", "S"].map((d, i) => (
          <li key={i} className="flex flex-col items-center gap-1">
            <span
              className={`flex size-[26px] items-center justify-center rounded-full border-[1.5px] ${i === me.today_idx ? "border-lime" : "border-line-strong"}`}
            >
              {me.daily_week[i] && <span className="size-4 rounded-full bg-text" />}
            </span>
            <span className="font-mono text-[10px] font-bold text-faint">{d}</span>
          </li>
        ))}
      </ol>
      <div className="flex items-end justify-between gap-3">
        <span>
          <span className="block font-mono text-[10px] font-bold tracking-[0.16em] text-faint">REMARKS</span>
          <RedPen className="text-xl">{remark}</RedPen>
        </span>
        <RedPen className="shrink-0 -rotate-6 text-base">— Tiko</RedPen>
      </div>
    </section>
  );
}

// Achievements as die-cut stickers: earned ones peel up when clicked.
function StickerBook({ me, saved, className = "" }: { me: Me; saved: boolean; className?: string }) {
  const stickers = [
    { id: "first", title: "First duel", icon: "⚡", tone: "bg-lime", earned: me.games_played >= 1 },
    { id: "win", title: "First win", icon: "🏆", tone: "bg-orange", earned: me.wins >= 1 },
    { id: "streak3", title: "3-day streak", icon: "🔥", tone: "bg-red-soft", earned: me.streak_best >= 3 },
    { id: "analyst", title: "Analyst", icon: "🛡️", tone: "bg-violet", earned: me.rating >= 1100 },
    { id: "college", title: "College top 3", icon: "🏛️", tone: "bg-[#5ce1e6]", earned: (me.college_rank ?? Infinity) <= 3 },
    { id: "week", title: "7-day streak", icon: "📅", tone: "bg-lime", earned: me.streak_best >= 7 },
    { id: "saved", title: "Account saved", icon: "🔒", tone: "bg-violet-soft", earned: saved },
    { id: "consultant", title: "Consultant", icon: "⭐", tone: "bg-orange", earned: me.rating >= 1300 },
  ];
  const earned = stickers.filter((s) => s.earned).length;
  return (
    <section className={`flex min-w-0 flex-col gap-2 rounded-[20px] border border-line bg-surface p-4 ${className}`}>
      <Heading aside={<span className="font-mono text-xs font-bold text-faint">{earned}/{stickers.length}</span>}>Sticker book</Heading>
      <ul className="-mx-1 flex gap-3.5 overflow-x-auto px-1 py-2.5 [scrollbar-width:none]">
        {stickers.map((s, i) => (
          <Sticker key={s.id} {...s} tilt={((i * 5) % 11) - 5} />
        ))}
      </ul>
    </section>
  );
}

function Sticker({ title, icon, tone, earned, tilt }: { title: string; icon: string; tone: string; earned: boolean; tilt: number }) {
  const [peel, setPeel] = useState(0);
  return (
    <li className="flex shrink-0 flex-col items-center gap-1.5">
      <button
        disabled={!earned}
        onClick={() => setPeel((n) => n + 1)}
        aria-label={`${title}: ${earned ? "earned" : "not earned yet"}`}
        style={{ rotate: `${tilt}deg` }}
        className="rounded-full disabled:cursor-default"
      >
        <span
          key={peel}
          className={`flex size-16 items-center justify-center rounded-full text-[26px] ${
            earned
              ? `border-4 border-white ${tone} drop-shadow-[2px_2px_2px_rgb(0_0_0/0.35)] ${peel ? "sticker-peel" : ""}`
              : "border-2 border-dashed border-line-strong text-lg text-faint"
          }`}
          style={{ transformOrigin: "100% 100%" }}
        >
          {earned ? icon : "?"}
        </span>
      </button>
      <span className={`text-[11px] font-bold whitespace-nowrap ${earned ? "text-soft" : "text-faint"}`}>{title}</span>
    </li>
  );
}

// A sticky note, taped on.
function StickyNote({ tone, tilt, title, line, onClick }: { tone: string; tilt: number; title: string; line: string; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      style={{ rotate: `${tilt}deg` }}
      className={`relative flex min-h-28 flex-col rounded-[3px] rounded-br-[14px] p-3.5 text-left text-ink shadow-[3px_5px_12px_rgb(0_0_0/0.35)] transition-transform hover:-translate-y-0.5 active:scale-[0.97] ${tone}`}
    >
      <span aria-hidden="true" className="absolute -top-2.5 left-1/2 h-[18px] w-14 -translate-x-1/2 bg-white/35" style={{ rotate: `${-tilt * 1.5}deg` }} />
      <span className="font-hand text-2xl leading-none font-bold">{title}</span>
      <span className="mt-1.5 text-xs font-semibold text-ink/70">{line}</span>
      <span aria-hidden="true" className="mt-auto self-end text-lg font-black">
        →
      </span>
    </button>
  );
}

function Row({ icon, title, detail, accent = false, onClick }: { icon: string; title: string; detail: string; accent?: boolean; onClick: () => void }) {
  return (
    <button onClick={onClick} className="flex min-h-[62px] w-full items-center gap-3.5 px-3.5 text-left transition hover:bg-raised">
      <span
        aria-hidden="true"
        className={`flex size-9 shrink-0 items-center justify-center rounded-[10px] text-base ${accent ? "bg-lime text-ink" : "bg-lime-tint text-lime"}`}
      >
        {icon}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block text-[15px] font-semibold">{title}</span>
        <span className="block truncate text-xs text-muted">{detail}</span>
      </span>
      <ChevronRight size={16} className="shrink-0 text-faint" />
    </button>
  );
}
