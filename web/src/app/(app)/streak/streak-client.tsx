"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api, type StreakInfo } from "@/lib/api";
import { useCompanionPage } from "@/lib/companion";
import { siteUrl } from "@/lib/format";
import { floorColor, istToday, istWeekday, MILESTONES, milestoneTitle, nextMilestone, type Celebration } from "@/lib/streak";
import { Bolt, ChevronLeft, Flame, Message } from "@/components/icons";
import { StreakBlock } from "@/components/streak-block";
import { StreakCelebration } from "@/components/streak-celebration";
import { Tiko } from "@/components/tiko";
import { Card, ErrorNote, Logo, Spinner } from "@/components/ui";

// The Streak Tower: your streak as a tower Tiko stands on, the next badge,
// the badge shelf, the days you played and your college's longest streaks.
export function StreakClient() {
  const router = useRouter();
  const [s, setS] = useState<StreakInfo | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  const [replay, setReplay] = useState<Celebration | null>(null);
  useCompanionPage({ mood: "cheer", hidden: true });

  useEffect(() => {
    let active = true;
    api
      .myStreak()
      .then((x) => active && (setS(x), setError(null)))
      .catch((e: Error) => active && setError(e.message));
    return () => {
      active = false;
    };
  }, [attempt]);

  return (
    <main className="mx-auto flex w-full max-w-[880px] flex-col gap-5 px-4 pt-5 pb-14 sm:px-6 lg:px-10 lg:pt-8">
      <div className="flex items-center justify-between gap-3">
        <Link href="/" className="flex items-center gap-1.5 text-sm font-semibold text-muted hover:text-text">
          <ChevronLeft size={18} /> Home
        </Link>
        <div className="lg:hidden">
          <Logo />
        </div>
      </div>
      {error && <ErrorNote message={error} onRetry={() => setAttempt((n) => n + 1)} />}
      {!s && !error && <Spinner label="Stacking your tower" />}
      {s && <Tower s={s} onReplay={() => setReplay({ kind: "up", from: Math.max(0, s.streak - 1), to: Math.max(1, s.streak), fresh: s.streak <= 1 })} />}
      {replay && (
        <StreakCelebration c={replay} onClose={() => setReplay(null)} onTower={() => setReplay(null)} onPlay={() => router.push("/play")} />
      )}
    </main>
  );
}

function Tower({ s, onReplay }: { s: StreakInfo; onReplay: () => void }) {
  const next = nextMilestone(s.streak);
  const prev = [...MILESTONES].reverse().find((m) => m <= s.streak) ?? 0;
  const shown = Math.min(s.streak, 8);
  const days = Array.from({ length: shown }, (_, i) => s.streak - i); // top → bottom
  const share = `🔥 I'm on a ${s.streak}-day streak on Apticks, quick 1v1 aptitude, coding and English duels. Can you build a taller tower? ${siteUrl("/")}`;

  return (
    <>
      <Card className="relative overflow-hidden p-5 sm:p-7">
        <div className="flex flex-wrap items-end justify-between gap-6">
          <div className="flex min-w-0 flex-[1_1_260px] flex-col gap-3">
            <span className="flex items-center gap-2 self-start rounded-full bg-orange-tint px-3 py-1.5 text-[13px] font-bold text-orange">
              <Flame size={14} strokeWidth={2.4} /> Your Streak Tower
            </span>
            <div className="flex items-baseline gap-3">
              <span className="font-display text-[clamp(64px,12vw,104px)] leading-none font-bold text-lime">
                {s.streak}
              </span>
              <span className="font-display text-2xl font-bold">{s.streak === 1 ? "day" : "days"}</span>
            </div>
            <p className="text-[15px] text-muted">
              {s.streak === 0
                ? "No tower yet. One duel today lays the first block."
                : s.played_today
                  ? `Today's block is on. Come back tomorrow for day ${s.streak + 1}.`
                  : `Play one duel today to stack day ${s.streak + 1}, or the tower falls at midnight.`}
            </p>
            <div className="flex flex-wrap gap-2 text-[13px]">
              <span className="rounded-full border border-line bg-raised px-3 py-1.5 font-semibold">Best: {s.best} days</span>
              {s.best > s.streak && <span className="rounded-full border border-line bg-raised px-3 py-1.5 font-semibold text-muted">{s.best - s.streak} to beat it</span>}
            </div>
            {next && (
              <div className="mt-1 flex flex-col gap-2">
                <div className="flex justify-between text-[13px] font-semibold">
                  <span>Next badge: {milestoneTitle(next)}</span>
                  <span className="font-mono text-muted">
                    {s.streak}/{next}
                  </span>
                </div>
                <div className="h-4 overflow-hidden rounded-full border-2 border-ink bg-raised">
                  <div className="h-full rounded-full bg-lime" style={{ width: `${Math.max(4, ((s.streak - prev) / (next - prev)) * 100)}%` }} />
                </div>
              </div>
            )}
            <div className="mt-2 flex flex-wrap gap-2.5">
              {!s.played_today && (
                <Link href="/play" className="pressable flex h-12 items-center gap-2 rounded-2xl bg-lime px-5 font-bold text-ink [--pop:#5f7710] hover:text-ink">
                  <Bolt size={18} strokeWidth={2.4} /> Play a duel
                </Link>
              )}
              {s.streak > 0 && (
                <button type="button" onClick={onReplay} className="flex h-12 items-center rounded-2xl border border-line bg-raised px-4 text-sm font-semibold hover:bg-line">
                  🎉 Replay today&apos;s moment
                </button>
              )}
              {s.streak > 1 && (
                <a href={`https://wa.me/?text=${encodeURIComponent(share)}`} target="_blank" rel="noopener noreferrer" className="flex h-12 items-center gap-2 rounded-2xl border border-line bg-raised px-4 text-sm font-semibold text-text hover:bg-line hover:text-text">
                  <Message size={16} /> Share
                </a>
              )}
            </div>
          </div>

          {/* The tower, newest block on top, Tiko standing on it. */}
          <div className="flex flex-[0_0_220px] flex-col items-center">
            <div className="relative" style={{ marginBottom: -6 }}>
              <Tiko mood={s.streak > 0 ? "cheer" : "think"} size={84} />
            </div>
            <div className="flex flex-col items-center gap-0">
              {s.streak === 0 ? (
                <div className="flex h-[66px] w-[200px] items-center justify-center rounded-[14px] border-[3px] border-dashed border-line text-sm font-semibold text-muted">
                  Day 1 goes here
                </div>
              ) : (
                days.map((d, i) => (
                  <div key={d} className="motion-safe:animate-[pop_0.5s_cubic-bezier(0.34,1.56,0.64,1)_both]" style={{ animationDelay: `${(shown - i) * 60}ms`, opacity: 1 - Math.max(0, i - 5) * 0.25 }}>
                    <StreakBlock day={d} weekday={istWeekday(s.streak - d + (s.played_today ? 0 : 1))} width={200} height={66} />
                  </div>
                ))
              )}
            </div>
            {s.streak > shown && <span className="mt-3 text-[13px] text-muted">+{s.streak - shown} more below</span>}
          </div>
        </div>
      </Card>

      {/* Badges: one per milestone, earned by your best streak. */}
      <Card className="flex flex-col gap-4 p-5">
        <h2 className="text-[17px] font-bold">Badges</h2>
        <div className="grid grid-cols-4 gap-3 sm:grid-cols-8">
          {MILESTONES.map((m) => {
            const got = s.best >= m;
            return (
              <div key={m} className="flex flex-col items-center gap-1.5 text-center" title={milestoneTitle(m)}>
                <div
                  className={`flex size-14 items-center justify-center rounded-full font-display text-lg font-bold ${got ? "border-[3px] border-ink text-ink" : "border-2 border-dashed border-line text-faint"}`}
                  style={got ? { background: floorColor(m), boxShadow: "4px 5px 0 #000" } : undefined}
                >
                  {got ? m : "🔒"}
                </div>
                <span className={`text-[11px] leading-tight font-semibold ${got ? "text-text" : "text-faint"}`}>{m} days</span>
              </div>
            );
          })}
        </div>
      </Card>

      <Calendar days={s.days} />

      {s.college && (
        <Card className="flex flex-col gap-3 p-5">
          <h2 className="text-[17px] font-bold">Longest streaks at {s.college}</h2>
          {s.college_top.length === 0 ? (
            <p className="text-sm text-muted">No live streaks here yet. Yours could be the first.</p>
          ) : (
            <ol className="flex flex-col gap-2">
              {s.college_top.map((r, i) => (
                <li key={`${i}-${r.name}`} className={`flex items-center gap-3 rounded-2xl border px-3 py-2.5 ${r.is_me ? "border-lime/60 bg-lime-tint" : "border-line bg-raised"}`}>
                  <span className="w-5 text-center font-mono text-sm font-bold text-muted">{i + 1}</span>
                  <span className="min-w-0 flex-1 truncate font-semibold">{r.is_me ? "You" : r.name}</span>
                  <span className="flex items-center gap-1 font-mono text-sm font-bold text-orange">
                    <Flame size={14} /> {r.streak}
                  </span>
                </li>
              ))}
            </ol>
          )}
        </Card>
      )}
    </>
  );
}

// The last eight weeks, Monday to Sunday: a brick for every day you played.
function Calendar({ days }: { days: string[] }) {
  const played = new Set(days);
  const today = istToday();
  const now = new Date();
  // Monday of the week eight weeks ago, in India.
  const dow = (["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"] as const).indexOf(istWeekday(0) as "MON");
  const cells = Array.from({ length: 56 }, (_, i) => {
    const back = 55 - i - (6 - dow);
    const date = istToday(new Date(now.getTime() - back * 86_400_000));
    return { date, back };
  });
  return (
    <Card className="flex flex-col gap-4 p-5">
      <div className="flex items-baseline justify-between">
        <h2 className="text-[17px] font-bold">Days you played</h2>
        <span className="text-[13px] text-muted">{days.length} in the last {Math.min(120, 56)} days</span>
      </div>
      <div className="grid grid-cols-7 gap-1.5 text-center font-mono text-[11px] font-bold text-faint">
        {["M", "T", "W", "T", "F", "S", "S"].map((d, i) => (
          <span key={i}>{d}</span>
        ))}
        {cells.map(({ date, back }) => {
          const on = played.has(date), isToday = date === today, future = back < 0;
          return (
            <span
              key={date}
              title={date}
              className={`aspect-square rounded-md ${on ? "border-2 border-ink" : future ? "" : "border border-line bg-raised"} ${isToday ? "ring-2 ring-lime ring-offset-2 ring-offset-surface" : ""}`}
              style={on ? { background: "#c8f135", boxShadow: "0 3px 0 #0b0e17" } : undefined}
            />
          );
        })}
      </div>
    </Card>
  );
}
