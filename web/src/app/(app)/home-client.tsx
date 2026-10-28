"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState, useSyncExternalStore } from "react";
import { api, type Board, type DuelSummary, type Me } from "@/lib/api";
import { COMPANIES } from "@/lib/companies";
import { challengeShareText, clock, greeting, inviteShareText, signed, tierFor, untilIstMidnight } from "@/lib/format";
import { Bolt, Calendar, Check, ChevronRight, Flame, Shield } from "@/components/icons";
import { SharePanel } from "@/components/share-panel";
import { useCompanionPage, type CompanionPage } from "@/lib/companion";
import { TikoTour } from "@/components/tiko-tour";
import { Avatar, BotTag, Card, ErrorNote, Logo, PlayerAvatar, Spinner, TierBadge } from "@/components/ui";

type Action = "quick" | "challenge" | "daily";

const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const LINK = "text-sm font-semibold text-lime hover:text-lime-hover";

const subscribeMinute = (cb: () => void) => {
  const t = setInterval(cb, 20_000);
  return () => clearInterval(t);
};
const currentMinute = () => Math.floor(Date.now() / 60_000);

export function HomeClient() {
  const router = useRouter();
  const [me, setMe] = useState<Me | null>(null);
  const [duels, setDuels] = useState<DuelSummary[]>([]);
  const [board, setBoard] = useState<Board | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  const [busy, setBusy] = useState<Action | null>(null);
  const minute = useSyncExternalStore(subscribeMinute, currentMinute, () => 0);
  useCompanionPage(homeNudge(me));

  useEffect(() => {
    let active = true;
    Promise.all([api.getMe(), api.myDuels(8), api.leaderboard("college", 5)])
      .then(([m, d, b]) => {
        if (!active) return;
        setMe(m);
        setDuels(d);
        setBoard(b);
        setError(null);
      })
      .catch((e: Error) => active && setError(e.message));
    return () => {
      active = false;
    };
  }, [attempt]);

  // Next keeps this page mounted (hidden) while a duel is open. Clear the
  // busy flag when it hides so Back doesn't show a stuck "Starting…".
  useEffect(() => () => setBusy(null), []);

  async function start(action: Action) {
    if (action === "quick") {
      router.push("/play"); // the matchmaking screen
      return;
    }
    setBusy(action);
    setError(null);
    try {
      if (action === "challenge") {
        // Stay here: the card turns into the invite link, and you play
        // your turn whenever you like, before or after your friend.
        await api.createChallenge();
        setDuels(await api.myDuels(8));
        setBusy(null);
        return;
      }
      const { duel_id } = await api.dailyChallenge();
      router.push(`/duel/${duel_id}`);
    } catch (e) {
      setError((e as Error).message);
      setBusy(null);
    }
  }

  if (!me) {
    return (
      <main className="mx-auto w-full max-w-[1180px] px-4 pt-6 sm:px-6 lg:px-10 lg:pt-8">
        <div className="lg:hidden">
          <Logo />
        </div>
        <div className="mt-6">
          {error ? (
            <ErrorNote message={error} onRetry={() => setAttempt((n) => n + 1)} />
          ) : (
            <Spinner label="Loading" />
          )}
        </div>
      </main>
    );
  }

  const tier = tierFor(me.rating);
  const hello = greeting(new Date(minute * 60_000));
  const isGuestName = /^Player \d{4}$/.test(me.name);
  // Your newest challenge link, while it can still be accepted (7 days).
  const latestChallenge = duels.find(
    (d) => d.code && minute * 60_000 - Date.parse(d.created_at) < 7 * 86_400_000,
  );

  return (
    <div className="flex-1 bg-[radial-gradient(900px_320px_at_20%_-80px,rgba(200,241,53,0.07),transparent),radial-gradient(700px_300px_at_95%_-60px,rgba(165,148,255,0.08),transparent)]">
      <main className="mx-auto flex w-full max-w-[1180px] flex-col gap-6 px-4 pt-5 pb-12 sm:px-6 lg:px-10 lg:pt-8">
        <header className="flex flex-wrap items-center justify-between gap-4">
          <div className="lg:hidden">
            <Logo />
          </div>
          <div className="hidden flex-col gap-2.5 lg:flex">
            <h1 className="font-display text-[clamp(22px,2.4vw,30px)] font-bold">
              {hello}, <Scribble>{me.name}</Scribble>
            </h1>
            <p className="text-[15px] text-muted">
              {tier.next ? (
                <>
                  You&apos;re <span className="font-mono font-bold text-text">{tier.toNext}</span> points from{" "}
                  {tier.next.name}.
                </>
              ) : (
                "You're in the top tier."
              )}
            </p>
          </div>
          <div className="flex items-center gap-2.5">
            <span className="flex h-10 items-center gap-1.5 rounded-full border border-orange/30 bg-orange-tint px-3.5 text-sm font-bold text-orange">
              <Flame size={16} strokeWidth={2.2} className={me.streak > 0 ? "motion-safe:animate-wiggle" : ""} />
              {me.streak > 0 ? (
                <span>
                  <span className="font-mono">{me.streak}</span>
                  <span className="sr-only sm:not-sr-only">-day streak</span>
                </span>
              ) : (
                <span>Start a streak</span>
              )}
            </span>
            <span className="hidden h-10 items-center gap-2 rounded-full border border-violet/30 bg-violet-tint px-3.5 text-sm font-bold text-violet lg:flex">
              <Shield size={15} strokeWidth={2.2} />
              <span className="font-mono">{me.rating.toLocaleString("en-IN")}</span> · {tier.name}
            </span>
            <Link href="/profile" aria-label="Your profile" className="rounded-full">
              <Avatar name={me.name} size={40} />
            </Link>
          </div>
        </header>

        <div className="flex flex-col gap-4 lg:hidden">
          <div>
            <p className="text-sm text-muted">{hello}</p>
            <h1 className="font-display text-xl font-bold">
              <Scribble>{me.name}</Scribble>
            </h1>
          </div>
          <RatingCard rating={me.rating} />
        </div>

        {isGuestName && (
          <Link
            href="/profile"
            className="flex items-center gap-3 rounded-2xl border border-line bg-surface px-4 py-3.5 text-sm text-text hover:bg-raised"
          >
            <span className="flex-1">
              <span className="font-semibold">Add your name and college</span>
              <span className="text-muted"> so friends know who beat them.</span>
            </span>
            <ChevronRight size={18} className="text-muted" />
          </Link>
        )}

        {error && <ErrorNote message={error} />}

        <div className="grid grid-cols-[repeat(auto-fit,minmax(280px,1fr))] gap-4">
          <QuickMatchCard />
          <ChallengeCard me={me} latest={latestChallenge} busy={busy} onStart={() => start("challenge")} />
          <DailyCard
            me={me}
            now={new Date(minute * 60_000)}
            resetsIn={untilIstMidnight(minute * 60_000)}
            busy={busy}
            onPlay={() => start("daily")}
          />
        </div>

        <CompanyCard />

        <TikoTour />

        <div className="flex flex-wrap items-start gap-4">
          <RecentDuels duels={duels} />
          <div className="flex min-w-0 flex-[1_1_300px] flex-col gap-4">
            <CollegeCard me={me} board={board} />
            <QuestsCard me={me} busy={busy} onAction={start} />
          </div>
        </div>
      </main>
    </div>
  );
}

// What Tiko says on the home page: the most useful nudge first.
function homeNudge(me: Me | null): CompanionPage {
  if (!me) return {};
  if (me.games_played === 0) return { mood: "wave", say: "Start your first duel and I'll cheer you on!" };
  if (me.streak > 0 && !me.played_today) {
    return { mood: "think", say: `Your ${me.streak}-day streak needs a duel today!` };
  }
  if (me.quests.daily === 0) return { mood: "point", say: "Today's Daily Challenge is waiting for you." };
  if (me.quests.quick_wins >= 2 && me.quests.accepted >= 1) {
    return { mood: "cheer", say: "Every goal done today. You're on fire!" };
  }
  return { mood: "happy" };
}

// Marker-pen squiggle under a word.
function Scribble({ children }: { children: React.ReactNode }) {
  return (
    <span className="relative inline-block whitespace-nowrap">
      {children}
      <svg
        aria-hidden="true"
        viewBox="0 0 200 12"
        preserveAspectRatio="none"
        className="absolute -bottom-2 left-0 h-2.5 w-full text-lime"
      >
        <path
          d="M3 8C28 3 50 10 78 6S128 2 158 7 188 6 197 4"
          fill="none"
          stroke="currentColor"
          strokeWidth="4"
          strokeLinecap="round"
        />
      </svg>
    </span>
  );
}

// Cards ease in one after another (see each card's animationDelay).
const CARD =
  "relative isolate flex flex-col gap-3.5 overflow-hidden rounded-[22px] border-2 p-[22px] sticker md:min-h-[244px] motion-safe:animate-rise";

function QuickMatchCard() {
  return (
    <div
      data-tour="quick"
      className={`${CARD} border-[#9fc41f] bg-lime bg-[repeating-linear-gradient(135deg,transparent_0_14px,rgb(11_14_23/0.035)_14px_28px)] text-ink [--pop:#5f7710]`}
    >
      <div className="flex items-start justify-between">
        <span className="-rotate-3 rounded-md bg-ink px-2 py-1 font-mono text-[11px] font-bold tracking-wider text-lime">
          1V1 · RATED
        </span>
        <span
          aria-hidden="true"
          className="sticker flex size-14 rotate-6 items-center justify-center rounded-2xl bg-ink font-display text-lg font-bold text-lime [--pop:#5f7710]"
        >
          VS
        </span>
      </div>
      <div className="flex flex-col gap-1">
        <h2 className="font-display text-[24px] leading-tight font-bold">Quick Match</h2>
        <p className="text-sm font-medium text-lime-ink">Race a player near your rating. 5 questions, about 3 minutes.</p>
      </div>
      <Link
        href="/play"
        className="pressable mt-auto flex h-12 items-center gap-2 self-start rounded-[14px] bg-ink px-5 text-[15px] font-bold text-text [--pop:#5f7710] hover:text-text"
      >
        <Bolt size={17} strokeWidth={2.4} className="text-lime" />
        Find opponent
      </Link>
    </div>
  );
}

function CompanyCard() {
  return (
    <Card data-tour="company" style={{ animationDelay: "200ms" }} className="flex flex-col gap-4 p-[22px] motion-safe:animate-rise">
      <div className="flex flex-col gap-1">
        <h2 className="text-[17px] font-bold">Practise for a company</h2>
        <p className="text-sm text-muted">A rated duel using only the topics on that company&apos;s aptitude test.</p>
      </div>
      <div className="grid grid-cols-[repeat(auto-fit,minmax(200px,1fr))] gap-3">
        {COMPANIES.map((c) => (
          <Link
            key={c.slug}
            href={`/play/${c.slug}`}
            className="group flex items-center gap-3 rounded-2xl border border-line bg-raised px-4 py-3.5 text-text hover:border-violet/60 hover:text-text"
          >
            <span className="min-w-0 flex-1">
              <span className="block font-bold">{c.name}</span>
              <span className="block text-xs text-muted">{c.blurb}</span>
            </span>
            <ChevronRight size={18} className="shrink-0 text-muted group-hover:text-violet" />
          </Link>
        ))}
      </div>
    </Card>
  );
}

// "You vs ?" shows what a challenge is before reading any text.
function VersusBadge({ name }: { name: string }) {
  return (
    <div aria-hidden="true" className="flex items-center">
      <span className="rounded-full ring-[3px] ring-surface">
        <Avatar name={name} size={42} />
      </span>
      <span className="z-10 -mx-2 -rotate-6 rounded-md bg-orange px-1.5 py-0.5 font-display text-[11px] font-bold text-ink ring-[3px] ring-surface">
        VS
      </span>
      <span className="flex size-[42px] items-center justify-center rounded-full border-2 border-dashed border-orange/70 bg-orange-tint font-display text-base font-bold text-orange ring-[3px] ring-surface">
        ?
      </span>
    </div>
  );
}

function ChallengeCard({
  me,
  latest,
  busy,
  onStart,
}: {
  me: Me;
  latest: DuelSummary | undefined;
  busy: Action | null;
  onStart: () => void;
}) {
  const button =
    "pressable flex h-12 items-center justify-center gap-1.5 rounded-[14px] border border-orange/40 bg-orange-tint text-[15px] font-bold text-orange [--pop:#6b3415] hover:text-orange disabled:opacity-70";
  return (
    <div
      data-tour="challenge"
      style={{ animationDelay: "70ms" }}
      className={`${CARD} border-orange/35 bg-surface bg-[radial-gradient(280px_200px_at_100%_0%,rgba(255,138,76,0.18),transparent)] [--pop:#4a2612]`}
    >
      <div className="flex items-start justify-between">
        <VersusBadge name={me.name} />
        <span className="rotate-3 rounded-md border border-orange/40 px-2 py-1 font-mono text-[11px] font-bold tracking-wider text-orange">
          VIA LINK
        </span>
      </div>
      <div className="flex flex-col gap-1">
        <h2 className="font-display text-[20px] leading-tight font-bold">Challenge a friend</h2>
        <p className="text-sm text-muted">
          Send a link. You both get the same 5 questions, and whoever plays second races the other&apos;s run.
        </p>
      </div>
      <div className="mt-auto flex flex-col gap-2.5">
        {latest?.code ? (
          <>
            <SharePanel
              quiet
              code={latest.code}
              text={
                latest.finished
                  ? challengeShareText(me.name, latest.correct, latest.total_ms, latest.code)
                  : inviteShareText(me.name, latest.code)
              }
            />
            {!latest.finished && (
              <Link href={`/duel/${latest.id}`} className={button}>
                Play your turn
                <ChevronRight size={18} />
              </Link>
            )}
            <button onClick={onStart} disabled={busy !== null} className={`self-start disabled:opacity-60 ${LINK}`}>
              {busy === "challenge" ? "Setting up…" : "New challenge"}
            </button>
          </>
        ) : (
          <button onClick={onStart} disabled={busy !== null} className={button}>
            {busy === "challenge" ? "Making your link…" : "Invite a friend"}
          </button>
        )}
      </div>
    </div>
  );
}

const MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

// A tear-off calendar page showing today's date.
function CalendarPage({ date }: { date: Date }) {
  return (
    <span
      aria-hidden="true"
      className="sticker flex w-[58px] rotate-6 flex-col overflow-hidden rounded-xl bg-text text-ink [--pop:#3a3270]"
    >
      <span className="relative flex h-5 items-center justify-center bg-violet font-mono text-[10px] font-bold tracking-wider text-ink">
        {MONTHS[date.getMonth()]}
        <span className="absolute top-0.5 left-2.5 size-1.5 rounded-full bg-ink/50" />
        <span className="absolute top-0.5 right-2.5 size-1.5 rounded-full bg-ink/50" />
      </span>
      <span className="py-1 text-center font-display text-[24px] leading-none font-bold">{date.getDate()}</span>
    </span>
  );
}

function DailyCard({
  me,
  now,
  resetsIn,
  busy,
  onPlay,
}: {
  me: Me;
  now: Date;
  resetsIn: string;
  busy: Action | null;
  onPlay: () => void;
}) {
  const doneToday = me.quests.daily > 0;
  return (
    <div
      data-tour="daily"
      style={{ animationDelay: "140ms" }}
      className={`${CARD} border-violet-strong bg-[linear-gradient(150deg,#251f4a_0%,#151a26_70%)] [--pop:#2c2660]`}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex flex-col gap-1">
          <h2 className="font-display text-[20px] leading-tight font-bold">Daily Challenge</h2>
          <p className="text-sm text-violet-soft/80">5 questions · same for everyone</p>
          <p className="font-mono text-xs text-violet">New set in {resetsIn}</p>
        </div>
        {now.getTime() > 0 && <CalendarPage date={now} />}
      </div>
      {/* The week as an OMR row: a bubble per day, filled in when done. */}
      <ol className="mt-auto grid grid-cols-7 gap-1.5" aria-label="Daily challenges this week">
        {DAYS.map((label, i) => {
          const done = me.daily_week[i];
          const today = i === me.today_idx;
          return (
            <li key={label} className="flex flex-col items-center gap-1">
              <span
                className={`flex size-[30px] items-center justify-center rounded-full border-2 font-mono text-[11px] font-bold ${
                  done
                    ? "border-lime bg-lime text-ink motion-safe:animate-pop"
                    : today
                      ? "border-dashed border-lime text-lime"
                      : "border-white/15 text-faint"
                }`}
                style={done ? { animationDelay: `${i * 60}ms` } : undefined}
              >
                {done ? <Check size={14} strokeWidth={3} /> : label[0]}
              </span>
              <span className="sr-only">
                {label}
                {done ? ", done" : today ? ", today" : ""}
              </span>
            </li>
          );
        })}
      </ol>
      <button
        onClick={onPlay}
        disabled={busy !== null}
        className={`pressable h-12 rounded-[14px] text-[15px] font-bold disabled:opacity-70 ${
          doneToday ? "border border-violet/40 bg-violet-tint text-violet-soft [--pop:#2c2660]" : "bg-text text-ink [--pop:#3a3270]"
        }`}
      >
        {busy === "daily" ? "Opening…" : doneToday ? "See today's rank" : "Play today's set"}
      </button>
    </div>
  );
}

function RatingCard({ rating }: { rating: number }) {
  const tier = tierFor(rating);
  return (
    <Card className="sticker flex flex-col gap-3.5 p-[18px]">
      <div className="flex items-start justify-between gap-3">
        <div className="flex flex-col gap-1">
          <span className="text-[13px] font-medium text-muted">Your rating</span>
          <span className="font-mono text-4xl font-bold tracking-tight">{rating.toLocaleString("en-IN")}</span>
        </div>
        <TierBadge rating={rating} />
      </div>
      <div className="flex flex-col gap-2">
        <div className="h-2 overflow-hidden rounded-full bg-line">
          <div className="h-full rounded-full bg-violet" style={{ width: `${Math.round(tier.progress * 100)}%` }} />
        </div>
        <div className="flex justify-between text-xs text-muted">
          <span>
            {tier.name} · <span className="font-mono">{tier.min.toLocaleString("en-IN")}</span>
          </span>
          <span>{tier.next ? `${tier.toNext} to ${tier.next.name}` : "Top tier"}</span>
        </div>
      </div>
    </Card>
  );
}

function RecentDuels({ duels }: { duels: DuelSummary[] }) {
  const rows = duels.map(describeDuel);
  return (
    <section
      aria-labelledby="recent"
      className="flex min-w-0 flex-[2_1_520px] flex-col gap-3.5 rounded-[22px] border border-line bg-surface p-[22px]"
    >
      <h2 id="recent" className="text-[17px] font-bold">
        Recent duels
      </h2>
      {rows.length === 0 ? (
        <p className="text-sm text-muted">No duels yet. A Quick Match takes about 3 minutes.</p>
      ) : (
        <>
          {/* Phones: one compact line per duel. */}
          <ul className="flex flex-col sm:hidden">
            {rows.map((r) => (
              <li key={r.id} className="border-t border-line first:border-t-0">
                <Link href={r.href} className="flex items-center gap-3 py-3 text-text hover:text-text">
                  <DuelAvatar r={r} />
                  <span className="flex min-w-0 flex-1 flex-col gap-1">
                    <span className="truncate text-sm font-semibold">
                      {r.who}
                      {r.bot && <BotTag />}
                    </span>
                    <span className="flex items-center gap-2">
                      <span className={`rounded-full px-2 py-0.5 text-[11px] font-bold ${r.chip.tone}`}>{r.chip.text}</span>
                      <span className="font-mono text-xs text-muted">{r.score}</span>
                    </span>
                  </span>
                  <Delta value={r.delta} />
                </Link>
              </li>
            ))}
          </ul>

          {/* Wider screens: the full table. */}
          <table className="hidden w-full border-collapse text-sm sm:table">
            <thead>
              <tr className="text-left text-xs tracking-[0.6px] text-muted uppercase">
                <th className="px-2 py-2.5 font-semibold">Opponent</th>
                <th className="px-2 py-2.5 font-semibold">Result</th>
                <th className="px-2 py-2.5 text-right font-semibold">Score</th>
                <th className="px-2 py-2.5 text-right font-semibold">Time</th>
                <th className="px-2 py-2.5 text-right font-semibold">Rating</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} className="border-t border-line">
                  <td className="px-2 py-3">
                    <Link href={r.href} className="flex items-center gap-2.5 text-text hover:text-text">
                      <DuelAvatar r={r} />
                      <span className="flex min-w-0 flex-col gap-px">
                        <span className="truncate font-semibold">
                          {r.who}
                          {r.bot && <BotTag />}
                        </span>
                        <span className="truncate text-xs text-muted">{r.sub}</span>
                      </span>
                    </Link>
                  </td>
                  <td className="px-2 py-3">
                    <span className={`rounded-full px-2.5 py-1 text-xs font-bold whitespace-nowrap ${r.chip.tone}`}>
                      {r.chip.text}
                    </span>
                  </td>
                  <td className="px-2 py-3 text-right font-mono whitespace-nowrap text-soft">{r.score}</td>
                  <td className="px-2 py-3 text-right font-mono text-soft">{r.time}</td>
                  <td className="px-2 py-3 text-right">
                    <Delta value={r.delta} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
    </section>
  );
}

type DuelLine = ReturnType<typeof describeDuel>;

// Everything a recent-duel line shows, worked out once for both layouts.
function describeDuel(d: DuelSummary) {
  const hasOpp = d.opponent_name !== null;
  const settled = d.finished && hasOpp && d.opponent_finished;
  const opp = d.opponent_score ?? 0;
  const tie = settled && d.score === opp && d.total_ms === d.opponent_total_ms;
  const won = settled && (d.score > opp || (d.score === opp && d.total_ms < (d.opponent_total_ms ?? 0)));

  let who = d.opponent_name ?? "";
  let sub = d.company
    ? `${d.company} practice`
    : (d.opponent_college ?? (d.mode === "quick" ? "Quick Match" : "Challenge"));
  if (d.mode === "daily") {
    who = "Daily Challenge";
    sub = "Same set for everyone";
  } else if (!hasOpp && d.mode === "quick") {
    who = "Solo run";
    sub = "Saved for others to race";
  } else if (!hasOpp) {
    who = "Your challenge";
    sub = "Waiting for a friend";
  } else if (d.is_replay) {
    sub = "Played your challenge";
  } else if (d.opponent_is_bot) {
    sub = d.company ? `${d.company} practice · bot` : "Practice bot";
  }

  let chip: { text: string; tone: string };
  if (!d.finished) chip = { text: "Unfinished", tone: "bg-orange-tint text-orange" };
  else if (d.mode === "daily") chip = { text: "Done", tone: "bg-violet-tint text-violet" };
  else if (!hasOpp) chip = { text: "Waiting", tone: "bg-raised text-muted" };
  else if (!d.opponent_finished) chip = { text: "Playing", tone: "bg-raised text-muted" };
  else if (tie) chip = { text: "Tie", tone: "bg-raised text-soft" };
  else if (won) chip = { text: "Won 🏆", tone: "bg-lime-tint text-lime" };
  else chip = { text: "Lost", tone: "bg-red-tint text-red-soft" };

  return {
    id: d.id,
    href: d.finished ? `/duel/${d.id}/result` : `/duel/${d.id}`,
    daily: d.mode === "daily",
    hasOpp,
    bot: d.opponent_is_bot,
    who,
    sub,
    chip,
    score: settled ? `${d.score} – ${opp}` : d.finished ? String(d.score) : "—",
    time: d.finished ? clock(d.total_ms) : "—",
    delta:
      d.rating_before !== null && d.rating_after !== null && !d.is_replay ? d.rating_after - d.rating_before : null,
  };
}

function DuelAvatar({ r }: { r: DuelLine }) {
  if (r.daily) {
    return (
      <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-violet-tint text-violet">
        <Calendar size={15} />
      </span>
    );
  }
  return <PlayerAvatar name={r.hasOpp ? r.who : "?"} bot={r.bot} size={32} />;
}

function Delta({ value }: { value: number | null }) {
  if (value === null) return <span className="font-mono text-sm text-faint">—</span>;
  return (
    <span className={`font-mono text-sm font-bold ${value >= 0 ? "text-lime" : "text-red-soft"}`}>{signed(value)}</span>
  );
}

function CollegeCard({ me, board }: { me: Me; board: Board | null }) {
  if (!me.college_id) {
    return (
      <Card className="flex flex-col gap-2 p-[22px]">
        <h2 className="text-[17px] font-bold">Your college board</h2>
        <p className="text-sm text-muted">Add your college to see where you rank against your batchmates.</p>
        <Link href="/profile" className={`mt-1 self-start ${LINK}`}>
          Add your college
        </Link>
      </Card>
    );
  }

  const rows = board?.rows ?? [];
  const mine = board?.me ?? null;
  const showMine = mine && !rows.some((r) => r.is_me);
  const hidden = mine ? mine.rank - 1 - rows.length : 0;

  return (
    <Card className="flex flex-col gap-3 p-[22px]">
      <div className="flex items-center justify-between gap-3">
        <h2 className="truncate text-[17px] font-bold">{me.college}</h2>
        <span className="shrink-0 text-xs text-muted">By rating</span>
      </div>
      {rows.length === 0 ? (
        <p className="text-sm text-muted">Nobody here is ranked yet. Play a duel to be first.</p>
      ) : (
        <ol className="flex flex-col">
          {rows.map((r) => (
            <BoardLine key={`${r.rank}-${r.name}`} row={r} />
          ))}
        </ol>
      )}
      {showMine && (
        <>
          {hidden > 0 && (
            <div className="flex items-center gap-2 text-xs text-faint">
              <span className="h-px flex-1 bg-line" />
              {hidden} more
              <span className="h-px flex-1 bg-line" />
            </div>
          )}
          <ol>
            <BoardLine row={mine} />
          </ol>
        </>
      )}
      <Link href="/leaderboard" className={`mt-1 self-start ${LINK}`}>
        Full leaderboard
      </Link>
    </Card>
  );
}

function BoardLine({ row }: { row: Board["rows"][number] }) {
  return (
    <li
      className={`flex min-h-11 items-center gap-3 rounded-xl ${
        row.is_me ? "-mx-2.5 border-[1.5px] border-lime bg-[#161d10] px-2.5" : ""
      }`}
    >
      <span className={`w-5 text-sm font-bold tabular-nums ${row.is_me ? "text-lime" : "text-muted"}`}>{row.rank}</span>
      <Avatar name={row.name} size={32} />
      <span className="min-w-0 flex-1 truncate text-sm font-semibold">{row.is_me ? "You" : row.name}</span>
      <span className="font-mono text-sm font-bold">{row.rating.toLocaleString("en-IN")}</span>
    </li>
  );
}

function QuestsCard({
  me,
  busy,
  onAction,
}: {
  me: Me;
  busy: Action | null;
  onAction: (a: Action) => void;
}) {
  const quests = [
    { title: "Play the Daily Challenge", have: me.quests.daily, need: 1, action: "daily" as const },
    { title: "Win 2 Quick Matches", have: me.quests.quick_wins, need: 2, action: "quick" as const },
    { title: "Get a friend to accept a challenge", have: me.quests.accepted, need: 1, action: "challenge" as const },
  ];
  const doneCount = quests.filter((q) => q.have >= q.need).length;

  return (
    <Card data-tour="goals" className="flex flex-col gap-2 p-[22px]">
      <div className="flex items-center justify-between">
        <h2 className="text-[17px] font-bold">Today&apos;s goals</h2>
        <span className="text-xs text-muted tabular-nums">
          {doneCount}/{quests.length} done
        </span>
      </div>
      <ul className="flex flex-col">
        {quests.map((q) => {
          const done = q.have >= q.need;
          return (
            <li key={q.title}>
              <button
                onClick={() => onAction(q.action)}
                disabled={done || busy !== null}
                className="-mx-2 flex min-h-12 w-[calc(100%+16px)] items-center gap-3 rounded-xl px-2 text-left hover:bg-raised disabled:cursor-default disabled:hover:bg-transparent"
              >
                {done ? (
                  <span className="flex size-6 shrink-0 items-center justify-center rounded-full bg-lime text-ink">
                    <Check size={13} strokeWidth={3} />
                  </span>
                ) : (
                  <span className="size-6 shrink-0 rounded-full border-2 border-line-strong" />
                )}
                <span className={`flex-1 text-sm font-semibold ${done ? "text-muted line-through" : ""}`}>{q.title}</span>
                <span className="font-mono text-xs font-semibold text-muted">
                  {Math.min(q.have, q.need)}/{q.need}
                </span>
              </button>
            </li>
          );
        })}
      </ul>
    </Card>
  );
}
