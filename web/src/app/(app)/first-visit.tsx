"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, type ReactNode } from "react";
import { Tiko } from "@/components/tiko";
import { COMPANIES } from "@/lib/companies";
import { Bars, Bolt, Calendar, ChevronRight, Clock, Swords } from "@/components/icons";
import { Modal } from "@/components/modal";
import { ErrorNote, Logo } from "@/components/ui";
import { DriveCard } from "./drive-card";
import { SubjectStage, SubjectTabs } from "./play-card";
import { useSubjectTab, type Subject } from "@/lib/subjects";

type Busy = "quick" | "challenge" | "daily" | null;

// The home page before your first game. It shows before your guest account
// exists, so a visitor from a reel sees it at once instead of a spinner.
//
// Most visitors come from an Instagram link on a phone, so on a phone
// everything fits on the first screen, one tap each: Play now, then the
// Daily, a friend duel, your test date, the leaderboard and every
// company's practice duel. Forms open in a sheet instead of making the page
// longer. Laptops get the roomier version with full cards below.
//
// The dashboard (rating, streak, quests, recent duels, Tiko's tour) comes
// after the first game: before it, it's all zeros.
export function FirstVisit({
  busy,
  error,
  onDaily,
  onFriend,
}: {
  busy: Busy;
  error: string | null;
  onDaily: () => void;
  onFriend: () => void;
}) {
  const [sheet, setSheet] = useState<"test" | "companies" | null>(null);
  const close = () => setSheet(null);
  // The four subjects on top, so a newcomer sees at once there's more
  // than aptitude. Play stays one tap in whichever is open.
  const [tab, setTab] = useSubjectTab();

  return (
    <div className="flex-1 bg-[radial-gradient(700px_320px_at_10%_-60px,rgba(200,241,53,0.09),transparent),radial-gradient(600px_300px_at_100%_0%,rgba(165,148,255,0.08),transparent)]">
      <main className="mx-auto flex w-full max-w-[1180px] flex-col gap-3 px-4 pt-4 pb-10 sm:px-6 lg:gap-5 lg:px-10 lg:pt-10">
        <div className="flex items-center justify-between gap-3 lg:hidden">
          <Logo />
          <span className="rounded-full border border-lime/30 bg-lime-tint px-3 py-1.5 font-mono text-[10px] font-bold tracking-wider text-lime">
            FREE · NO SIGN-UP
          </span>
        </div>

        {error && <ErrorNote message={error} />}

        <div className="grid gap-3 lg:grid-cols-[1.35fr_1fr] lg:items-stretch lg:gap-5">
          <div className="flex flex-col">
            <SubjectTabs current={tab} onPick={setTab} />
            <SubjectStage current={tab}>
              {(t) => (t === "gk" ? <SoonHero which={t} onBack={() => setTab("aptitude")} /> : <Hero subject={t} />)}
            </SubjectStage>
          </div>
          <div className="hidden flex-col gap-4 lg:mt-[74px] lg:flex">
            <SampleQuestion />
            <Tile
              tone="violet"
              icon={<Calendar size={18} strokeWidth={2.2} />}
              title={busy === "daily" ? "Opening…" : "Daily Challenge"}
              note="Same 5 for everyone"
              onClick={onDaily}
              disabled={busy !== null}
            />
            <Tile
              tone="orange"
              icon={<Swords size={18} strokeWidth={2.2} />}
              title={busy === "challenge" ? "Opening a room…" : "Duel a friend"}
              note="Send a link, race them live"
              onClick={onFriend}
              disabled={busy !== null}
            />
          </div>
        </div>

        {/* Phones: the rest of Apticks on the same screen. */}
        <div className="flex flex-col gap-3 lg:hidden">
          <div className="grid grid-cols-2 gap-2.5">
            <MiniTile
              tone="violet"
              icon={<Calendar size={17} strokeWidth={2.2} />}
              title={busy === "daily" ? "Opening…" : "Daily"}
              note="Same 5 for all"
              onClick={onDaily}
              disabled={busy !== null}
              delay={60}
            />
            <MiniTile
              tone="orange"
              icon={<Swords size={17} strokeWidth={2.2} />}
              title={busy === "challenge" ? "Opening…" : "Duel a friend"}
              note="Race them live"
              onClick={onFriend}
              disabled={busy !== null}
              delay={100}
            />
            <MiniTile
              tone="plain"
              icon={<Clock size={17} strokeWidth={2.2} />}
              title="My test date"
              note="Count down to it"
              onClick={() => setSheet("test")}
              delay={140}
            />
            <MiniTile
              tone="lime"
              icon={<Bars size={17} strokeWidth={2.4} />}
              title="Leaderboard"
              note="College & everyone"
              href="/leaderboard"
              delay={180}
            />
          </div>
          <CompanyStrip onAll={() => setSheet("companies")} />
        </div>

        {/* Laptops: room for the full cards. */}
        <section aria-labelledby="more-title" className="hidden flex-col gap-5 pt-6 lg:flex">
          <div className="flex flex-col items-start gap-2">
            <span className="rotate-2 rounded-md border border-line-strong px-2 py-1 font-mono text-[11px] font-bold tracking-wider text-muted">
              OR LOOK AROUND FIRST
            </span>
            <h2 id="more-title" className="font-display text-[28px] leading-tight font-bold">
              More ways to prepare
            </h2>
          </div>
          <CompanyPicks />
          <div className="grid grid-cols-[1.35fr_1fr] items-stretch gap-5">
            {/* The same card as on the dashboard, raised like the rest here. */}
            <div className="sticker flex flex-col rounded-[20px] [--pop:#2c2660] motion-safe:animate-rise [&>*]:flex-1">
              <DriveCard />
            </div>
            <LeaderboardCard />
          </div>
        </section>
      </main>

      <Modal open={sheet === "test"} onClose={close} title="Your placement test">
        <DriveCard />
      </Modal>
      <Modal open={sheet === "companies"} onClose={close} title="Practise for a company">
        <p className="-mt-2 text-sm text-muted">A rated duel on only the topics that company&apos;s aptitude test asks.</p>
        <CompanyGrid />
      </Modal>
    </div>
  );
}

const HERO = {
  aptitude: {
    box: "border-[#9fc41f] bg-lime bg-[repeating-linear-gradient(135deg,transparent_0_14px,rgb(11_14_23/0.035)_14px_28px)] [--pop:#5f7710]",
    tag: "APTITUDE · 1V1",
    sticker: "VS",
    title: "Aptitude, but it's a duel.",
    blurb: (
      <>
        Race someone through 5 placement-style questions<span className="hidden lg:inline">: quant and reasoning</span>.
        Right and fast wins.
      </>
    ),
    sub: "text-lime-ink",
    accent: "text-lime",
    pop: "[--pop:#5f7710]",
    href: "/play",
    minutes: "3 MIN",
    bubble: "Tap Play! I'll find you a rival.",
  },
  coding: {
    box: "border-[#8676e6] bg-violet bg-[repeating-linear-gradient(90deg,transparent_0_22px,rgb(11_14_23/0.05)_22px_23px)] [--pop:#4b3fa6]",
    tag: "CODING · 1V1",
    sticker: "</>",
    title: "Code, but it's a duel.",
    blurb: <>Read 5 short programs and call the output before your rival. In C, C++, Java, Python or pseudocode.</>,
    sub: "text-[#241d5c]",
    accent: "text-violet",
    pop: "[--pop:#4b3fa6]",
    href: "/play/coding",
    minutes: "4 MIN",
    bubble: "Tap Play! Pick your language in the duel.",
  },
  english: {
    box: "border-[#d4683a] bg-orange bg-[repeating-linear-gradient(45deg,transparent_0_16px,rgb(11_14_23/0.04)_16px_17px)] [--pop:#9c4a1f]",
    tag: "ENGLISH · 1V1",
    sticker: "Aa",
    title: "English, but it's a duel.",
    blurb: <>Synonyms, idioms, grammar and more: 5 questions the way placement tests ask them. Right and fast wins.</>,
    sub: "text-[#4a1f08]",
    accent: "text-orange",
    pop: "[--pop:#9c4a1f]",
    href: "/play/english",
    minutes: "3 MIN",
    bubble: "Tap Play! Words are my thing.",
  },
} as const;

function Hero({ subject }: { subject: Subject }) {
  const router = useRouter();
  const h = HERO[subject];
  // Tapping Tiko starts a duel too, after Tiko's little reaction.
  const play = () => router.push(h.href);
  return (
    <section
      aria-labelledby="first-title"
      className={`relative isolate flex flex-1 flex-col gap-3 overflow-hidden rounded-[24px] border-2 p-[18px] text-ink sticker motion-safe:animate-rise lg:gap-4 lg:p-9 ${h.box}`}
    >
      {/* Phones skip this row: Tiko below does its job, in less room. */}
      <div className="hidden items-start justify-between lg:flex">
        <span className="-rotate-3 rounded-md bg-ink px-2 py-1 font-mono text-[11px] font-bold tracking-wider text-lime">{h.tag}</span>
        <span
          aria-hidden="true"
          className={`sticker hidden size-16 rotate-6 items-center justify-center rounded-2xl bg-ink font-display font-bold lg:flex ${
            subject === "coding" ? "font-mono text-base" : "text-lg"
          } ${h.accent} ${h.pop}`}
        >
          {h.sticker}
        </span>
      </div>
      <div className="flex flex-col gap-1.5 lg:gap-2">
        <h1 id="first-title" className="font-display text-[clamp(26px,7.4vw,46px)] leading-[1.08] font-bold">
          {h.title}
        </h1>
        <p className={`text-[14px] font-medium lg:max-w-[46ch] lg:text-base ${h.sub}`}>{h.blurb}</p>
      </div>
      <div className="mt-auto flex flex-col gap-2 pt-1">
        {/* Phones: Tiko stands on the button and asks you to press it. */}
        <div className="relative z-10 -mb-2.5 flex items-end justify-end gap-1 pr-1 lg:hidden">
          <Bubble className="mb-7">{h.bubble}</Bubble>
          <Tiko mood="point" size={62} onTap={play} />
        </div>
        <Link
          href={h.href}
          className={`pressable flex h-[52px] items-center justify-center gap-2 rounded-2xl bg-ink px-6 text-[17px] font-bold text-text hover:text-text lg:h-14 lg:self-start lg:px-10 ${h.pop}`}
        >
          <Bolt size={19} strokeWidth={2.4} className={h.accent} />
          Play now
          <span className={`ml-1 rounded-full bg-text/10 px-2 py-0.5 font-mono text-[11px] font-bold lg:hidden ${h.accent}`}>{h.minutes}</span>
        </Link>
        <p className={`hidden text-[13px] font-semibold lg:block ${h.sub}`}>
          Free · no sign-up · about {subject === "coding" ? 4 : 3} minutes
        </p>
      </div>
      {/* Laptops: Tiko in the hero's empty corner, beside the button. */}
      <div className="absolute right-8 bottom-6 hidden items-end gap-1 lg:flex">
        <Bubble className="mb-20 max-w-[180px]">{h.bubble}</Bubble>
        <Tiko mood="wave" size={112} onTap={play} />
      </div>
    </section>
  );
}

// A speech bubble from Tiko, popping in just after the page.
const SOON_HERO = {
  gk: {
    box: "border-[#2f6f8f] bg-[#10222c] [--pop:#0b1a22]",
    accent: "text-[#6cc7ff]",
    title: "GK is coming soon.",
    blurb: "Static GK and current affairs for bank and government exams. Aptitude, Coding and English are ready now.",
  },
} as const;

function SoonHero({ which, onBack }: { which: "gk"; onBack: () => void }) {
  const h = SOON_HERO[which];
  return (
    <section
      aria-labelledby="first-title"
      className={`relative isolate flex flex-1 flex-col gap-3 overflow-hidden rounded-[24px] border-2 p-[18px] text-text sticker motion-safe:animate-rise lg:gap-4 lg:p-9 ${h.box}`}
    >
      <span className={`-rotate-3 self-start rounded-md bg-ink px-2 py-1 font-mono text-[11px] font-bold tracking-wider ${h.accent}`}>
        COMING SOON
      </span>
      <div className="flex flex-col gap-1.5 lg:gap-2">
        <h1 id="first-title" className="font-display text-[clamp(26px,7.4vw,46px)] leading-[1.08] font-bold">
          {h.title}
        </h1>
        <p className="text-[14px] font-medium text-soft lg:max-w-[46ch] lg:text-base">{h.blurb}</p>
      </div>
      <button
        onClick={onBack}
        className="pressable mt-auto flex h-[52px] items-center justify-center gap-2 rounded-2xl border-2 border-line bg-ink px-6 text-[17px] font-bold text-text [--pop:#0b0e17] lg:h-14 lg:self-start lg:px-10"
      >
        <Bolt size={19} strokeWidth={2.4} className="text-lime" />
        Play Aptitude now
      </button>
    </section>
  );
}

function Bubble({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <span
      style={{ animationDelay: "650ms" }}
      className={`rounded-2xl rounded-br-[4px] border-2 border-ink bg-text px-3 py-1.5 text-[13px] leading-snug font-bold text-ink motion-safe:animate-pop ${className}`}
    >
      {children}
    </span>
  );
}

const MINI = {
  violet: "border-violet/35 bg-violet-tint/60 text-violet [--pop:#2c2660]",
  orange: "border-orange/35 bg-orange-tint/70 text-orange [--pop:#4a2612]",
  plain: "border-line-strong bg-raised text-violet-soft [--pop:#0b0e17]",
  lime: "border-lime/30 bg-lime-tint text-lime [--pop:#3b4a12]",
};

// A phone tile: icon, name and a few words, the whole tile one button.
function MiniTile({
  tone,
  icon,
  title,
  note,
  onClick,
  href,
  disabled,
  delay,
}: {
  tone: keyof typeof MINI;
  icon: ReactNode;
  title: string;
  note: string;
  onClick?: () => void;
  href?: string;
  disabled?: boolean;
  delay: number;
}) {
  const className = `pressable sticker flex min-w-0 items-center gap-2.5 rounded-[16px] border-2 px-3 py-2 text-left motion-safe:animate-rise disabled:opacity-70 ${MINI[tone]}`;
  const inner = (
    <>
      <span className="flex size-8 shrink-0 items-center justify-center rounded-lg bg-ink/40">{icon}</span>
      <span className="flex min-w-0 flex-col">
        <span className="truncate text-[14px] font-bold text-text">{title}</span>
        <span className="truncate text-[12px] text-muted">{note}</span>
      </span>
    </>
  );
  const style = { animationDelay: `${delay}ms` };
  return href ? (
    <Link href={href} style={style} className={`${className} hover:text-current`}>
      {inner}
    </Link>
  ) : (
    <button onClick={onClick} disabled={disabled} style={style} className={className}>
      {inner}
    </button>
  );
}

// A company's short badge: "TCS NQT" → TCS, "Tech Mahindra" → TM,
// "Infosys" → IN.
function badge(name: string) {
  const words = name.split(" ");
  if (words[0].length <= 4 && words[0] === words[0].toUpperCase()) return words[0];
  if (words.length > 1) return words.map((w) => w[0]).join("").slice(0, 3).toUpperCase();
  return name.slice(0, 2).toUpperCase();
}

// Phones: every company in one row you swipe through, edge to edge.
function CompanyStrip({ onAll }: { onAll: () => void }) {
  return (
    <section aria-labelledby="companies-title" className="flex flex-col gap-2" style={{ animationDelay: "220ms" }}>
      <div className="flex items-baseline justify-between gap-3">
        <h2 id="companies-title" className="text-[15px] font-bold">
          Practise for a company
        </h2>
        <button onClick={onAll} className="flex items-center text-sm font-semibold text-violet">
          All {COMPANIES.length}
          <ChevronRight size={15} />
        </button>
      </div>
      <div className="-mx-4 flex snap-x gap-2 overflow-x-auto px-4 pb-1 [scrollbar-width:none] sm:-mx-6 sm:px-6 [&::-webkit-scrollbar]:hidden">
        {COMPANIES.map((c) => (
          <Link
            key={c.slug}
            href={`/play/${c.slug}`}
            className="flex shrink-0 snap-start items-center gap-2 rounded-full border border-line bg-raised py-1.5 pr-3.5 pl-1.5 text-sm font-bold text-text hover:border-violet/60 hover:text-text"
          >
            <span
              aria-hidden="true"
              className="flex h-7 min-w-9 items-center justify-center rounded-full px-1.5 font-mono text-[10px] font-bold text-white"
              style={{ backgroundColor: c.color }}
            >
              {badge(c.name)}
            </span>
            {c.name}
          </Link>
        ))}
      </div>
    </section>
  );
}

// Every company's practice duel as a grid, one tap each.
function CompanyGrid() {
  return (
    <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3 lg:grid-cols-4">
      {COMPANIES.map((c) => (
        <Link
          key={c.slug}
          href={`/play/${c.slug}`}
          className="pressable group flex min-w-0 items-center gap-2.5 rounded-2xl border border-line bg-raised px-2.5 py-2.5 text-text [--pop:#0b0e17] hover:border-violet/60 hover:text-text sm:gap-3 sm:px-3"
        >
          <span
            aria-hidden="true"
            className="flex h-8 w-9 shrink-0 items-center justify-center rounded-lg font-mono text-[10px] font-bold tracking-wide text-white sm:h-9 sm:w-11 sm:text-[11px]"
            style={{ backgroundColor: c.color }}
          >
            {badge(c.name)}
          </span>
          <span className="flex min-w-0 flex-col">
            <span className="text-[13px] leading-tight font-bold sm:truncate sm:text-sm">{c.name}</span>
            <span className="hidden truncate text-xs text-muted sm:block">{c.blurb}</span>
          </span>
        </Link>
      ))}
    </div>
  );
}

// Laptops: the company grid in its own card.
function CompanyPicks() {
  return (
    <div className="sticker flex flex-col gap-5 rounded-[22px] border-2 border-violet/35 bg-surface bg-[radial-gradient(520px_220px_at_100%_0%,rgba(165,148,255,0.16),transparent)] p-7 [--pop:#2c2660] motion-safe:animate-rise">
      <div className="flex items-start justify-between gap-3">
        <div className="flex flex-col gap-1.5">
          <h3 className="font-display text-[19px] leading-tight font-bold">Practise for a company</h3>
          <p className="text-sm text-muted">
            A rated duel on only the topics that company&apos;s aptitude test asks. Pick yours.
          </p>
        </div>
        <span className="flex shrink-0 -rotate-3 flex-col items-center rounded-xl bg-violet px-2.5 py-1.5 text-ink">
          <span className="font-display text-lg leading-none font-bold">{COMPANIES.length}</span>
          <span className="font-mono text-[9px] font-bold tracking-wider">TESTS</span>
        </span>
      </div>
      <CompanyGrid />
    </div>
  );
}

// Where you'd rank, with a little podium so it reads before the words do.
function LeaderboardCard() {
  return (
    <Link
      href="/leaderboard"
      style={{ animationDelay: "70ms" }}
      className="pressable sticker group flex items-end justify-between gap-4 rounded-[20px] border-2 border-lime/30 bg-surface bg-[radial-gradient(360px_200px_at_100%_100%,rgba(200,241,53,0.12),transparent)] p-[22px] text-text [--pop:#3b4a12] motion-safe:animate-rise hover:text-text"
    >
      <span className="flex min-w-0 flex-col gap-1.5 self-center">
        <span className="flex items-center gap-2 text-lime">
          <Bars size={18} strokeWidth={2.4} />
          <span className="font-mono text-[11px] font-bold tracking-wider">RANKS</span>
        </span>
        <span className="font-display text-[19px] leading-tight font-bold">Climb the leaderboard</span>
        <span className="text-sm text-muted">Your college&apos;s board and everyone&apos;s. Every duel moves your rating.</span>
        <span className="mt-1 flex items-center gap-1 text-sm font-bold text-lime">
          See who&apos;s on top <ChevronRight size={16} className="transition-transform group-hover:translate-x-0.5" />
        </span>
      </span>
      <span aria-hidden="true" className="flex shrink-0 items-end gap-1.5">
        {[
          { place: 2, h: "h-12", tone: "bg-soft text-ink" },
          { place: 1, h: "h-[72px]", tone: "bg-lime text-ink" },
          { place: 3, h: "h-9", tone: "bg-orange text-ink" },
        ].map((s) => (
          <span key={s.place} className={`flex w-9 ${s.h} items-start justify-center rounded-t-lg pt-1.5 font-display text-sm font-bold ${s.tone}`}>
            {s.place}
          </span>
        ))}
      </span>
    </Link>
  );
}

const TONES = {
  violet: "border-violet/35 bg-violet-tint/60 text-violet [--pop:#2c2660]",
  orange: "border-orange/35 bg-orange-tint/70 text-orange [--pop:#4a2612]",
};

// Laptops: a wide tile beside the hero.
function Tile({
  tone,
  icon,
  title,
  note,
  onClick,
  disabled,
}: {
  tone: keyof typeof TONES;
  icon: ReactNode;
  title: string;
  note: string;
  onClick: () => void;
  disabled: boolean;
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`pressable sticker flex items-center gap-3 rounded-[18px] border-2 p-4 text-left motion-safe:animate-rise disabled:opacity-70 ${TONES[tone]}`}
    >
      <span className="flex size-8 shrink-0 items-center justify-center rounded-lg bg-ink/40">{icon}</span>
      <span className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="text-[15px] font-bold text-text">{title}</span>
        <span className="text-[13px] leading-snug text-muted">{note}</span>
      </span>
      <ChevronRight size={18} className="text-muted" />
    </button>
  );
}

// What a question looks like, so the page shows the game and not only
// talks about it. Laptops only: on a phone the button comes first.
function SampleQuestion() {
  return (
    <div
      aria-hidden="true"
      style={{ animationDelay: "40ms" }}
      className="flex flex-col gap-3 rounded-[20px] border-2 border-line bg-surface p-5 sticker motion-safe:animate-rise"
    >
      <div className="flex items-center justify-between font-mono text-[11px] font-bold tracking-wider text-faint">
        <span>QUANT · Q 2 OF 5</span>
        <span className="text-lime">0:07</span>
      </div>
      <p className="text-[15px] font-semibold text-text">A does a job in 12 days, B in 6. Working together, how many days?</p>
      <div className="grid grid-cols-2 gap-2 text-sm font-semibold">
        <span className="rounded-xl border border-line bg-raised px-3 py-2.5 text-soft">3 days</span>
        <span className="rounded-xl border-2 border-lime bg-lime-tint px-3 py-2.5 text-lime">4 days ✓</span>
        <span className="rounded-xl border border-line bg-raised px-3 py-2.5 text-soft">6 days</span>
        <span className="rounded-xl border border-line bg-raised px-3 py-2.5 text-soft">9 days</span>
      </div>
      <div className="flex items-center gap-2 text-[13px] text-muted">
        <span className="h-1.5 flex-1 overflow-hidden rounded-full bg-raised">
          <span className="block h-full w-[40%] rounded-full bg-lime" />
        </span>
        <span>You 2 · 1 Rival</span>
      </div>
    </div>
  );
}
