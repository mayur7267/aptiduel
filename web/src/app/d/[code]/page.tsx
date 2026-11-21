import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import type { DailyShare } from "@/lib/api";
import { getDailyShare } from "@/lib/daily-share";
import { clock, shortDay } from "@/lib/format";
import { Bolt, Calendar, Check, Close } from "@/components/icons";
import { Avatar, Logo } from "@/components/ui";
import { Tiko } from "@/components/tiko";
import { ArrivalTag } from "./arrival-tag";

// A friend's shared Daily result: who sent it and how they did, right or
// wrong per question but never the questions, and a button to play today's.

const which = (r: DailyShare) => (r.today ? "today's" : `the ${shortDay(r.day)}`);

export async function generateMetadata({ params }: PageProps<"/d/[code]">): Promise<Metadata> {
  const { code } = await params;
  const r = await getDailyShare(code).catch(() => null);
  if (!r) return { title: "Daily result not found" };
  const title = `${r.name} got ${r.correct}/5 on ${which(r)} Apticks Daily`;
  const description = "Same 5 placement aptitude questions for everyone, every day. About 3 minutes, no sign-up. Can you beat it?";
  return { title, description, openGraph: { title, description }, robots: { index: false } };
}

export default function DailySharePage({ params }: PageProps<"/d/[code]">) {
  return (
    <div className="flex min-h-full flex-1 flex-col">
      <header className="border-b border-[#1c2232]">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-4 sm:px-6">
          <Logo />
          <Link href="/" className="rounded-xl border border-line bg-surface px-4 py-2.5 text-sm font-semibold text-text hover:bg-raised">
            Explore Apticks
          </Link>
        </div>
      </header>

      <main className="flex-1">
        <Suspense
          fallback={
            <section className="mx-auto max-w-6xl px-4 py-12 sm:px-6 sm:py-16">
              <Skeleton />
            </section>
          }
        >
          <Body params={params} />
        </Suspense>
      </main>

      <footer className="border-t border-[#1c2232]">
        <div className="mx-auto max-w-6xl px-4 py-6 text-[13px] text-faint sm:px-6">
          © 2026 Apticks · Questions are original, written in the style of placement aptitude tests. ·{" "}
          <Link href="/privacy" className="underline hover:text-text">Privacy</Link> ·{" "}
          <Link href="/support" className="underline hover:text-text">Help</Link>
        </div>
      </footer>
    </div>
  );
}

const STEPS = [
  ["01", "Same 5 for everyone", "Every player gets the same questions today: quant and reasoning."],
  ["02", "Fast and right wins", "100 points for every correct answer, plus up to 50 for speed. One try a day."],
  ["03", "Keep your streak", "A new set every midnight. Play daily to build a streak and climb today's ranks."],
];

async function Body({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  const r = await getDailyShare(code);
  if (!r) notFound();

  return (
    <>
      <ArrivalTag code={code} />
      <section className="mx-auto flex max-w-6xl flex-wrap items-center gap-10 px-4 py-10 sm:px-6 sm:py-16">
        <div className="flex min-w-0 flex-[1_1_480px] flex-col gap-5">
          <span className="flex items-center gap-2 self-start rounded-full bg-violet-tint px-3 py-1.5 text-[13px] font-bold text-violet-soft">
            <Calendar size={14} strokeWidth={2.4} />
            {r.today ? "Today's Daily Challenge" : `Daily Challenge · ${shortDay(r.day)}`}
          </span>
          <h1 className="font-display text-[clamp(30px,4.6vw,54px)] leading-[1.08] font-bold tracking-tight">
            {r.name} got {r.correct}/5 on {which(r)} Daily. Can you beat it?
          </h1>
          <p className="max-w-[520px] text-lg leading-relaxed text-muted">
            {r.today
              ? "Everyone gets the same 5 placement-style questions today. About 3 minutes, no sign-up."
              : "That set is closed, but today's is waiting: 5 new placement-style questions, the same for everyone. About 3 minutes, no sign-up."}
          </p>

          <Link
            href="/daily"
            className="pressable flex h-14 items-center justify-center gap-2.5 self-stretch rounded-2xl bg-lime px-8 text-[17px] font-bold text-ink [--pop:#5f7710] hover:text-ink sm:self-start"
          >
            <Bolt size={20} strokeWidth={2.4} />
            Play today&apos;s Daily
          </Link>
          <Link href="/play" className="-mt-1 self-center text-sm font-semibold text-muted hover:text-text sm:self-start">
            Or race someone in a quick 1v1 duel
          </Link>

          <div className="flex flex-wrap gap-x-5 gap-y-2 text-[13px] text-muted">
            {["Free", "Works in any browser", "No answers given away"].map((t) => (
              <span key={t} className="flex items-center gap-1.5">
                <Check size={14} strokeWidth={3} className="text-lime" />
                {t}
              </span>
            ))}
          </div>
        </div>

        <div className="flex min-w-0 flex-[1_1_360px] justify-center pt-10">
          {/* Tiko perches on the score card, waving the friend in. */}
          <div className="relative w-full max-w-[420px]">
            <ScoreCard r={r} />
            <Tiko mood="wave" size={84} className="absolute -top-[72px] -left-3 z-10" />
          </div>
        </div>
      </section>

      <section className="border-t border-[#1c2232] bg-[#0e121c]">
        <div className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-14 sm:px-6">
          <h2 className="font-display text-2xl font-bold sm:text-3xl">How the Daily works</h2>
          <div className="grid gap-4 sm:grid-cols-3">
            {STEPS.map(([n, title, body]) => (
              <div key={n} className="flex flex-col gap-2.5 rounded-[20px] border border-line bg-surface p-5">
                <span className="font-display text-2xl font-bold text-lime">{n}</span>
                <span className="text-[17px] font-bold">{title}</span>
                <span className="text-[15px] leading-relaxed text-muted">{body}</span>
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}

// Their result, right or wrong per question.
function ScoreCard({ r }: { r: DailyShare }) {
  return (
    <div className="sticker flex w-full rotate-1 flex-col gap-5 rounded-[28px] border-2 border-violet/40 bg-surface p-6 [--pop:#2c2660]">
      <div className="flex items-center gap-3">
        <Avatar name={r.name} size={48} ring="border-2 border-violet" />
        <div className="flex min-w-0 flex-col">
          <span className="truncate font-bold">{r.name}</span>
          <span className="text-[13px] text-muted">{r.today ? "Played today" : `Played ${shortDay(r.day)}`}</span>
        </div>
        <span className="ml-auto font-display text-[34px] leading-none font-bold">{r.correct}/5</span>
      </div>
      <div className="grid grid-cols-5 gap-2">
        {r.grid.map((ok, i) =>
          ok ? (
            <span key={i} className="flex aspect-square items-center justify-center rounded-xl bg-lime text-ink">
              <Check size={20} strokeWidth={3.2} />
              <span className="sr-only">Question {i + 1} right</span>
            </span>
          ) : (
            <span key={i} className="flex aspect-square items-center justify-center rounded-xl bg-red-tint text-red">
              <Close size={18} strokeWidth={3.2} />
              <span className="sr-only">Question {i + 1} wrong</span>
            </span>
          ),
        )}
      </div>
      <div className="flex items-center justify-between font-mono text-sm text-soft">
        <span>{clock(r.total_ms)}</span>
        <span>{r.score} points</span>
      </div>
    </div>
  );
}

function Skeleton() {
  return (
    <div aria-hidden="true" className="flex animate-pulse flex-col gap-5">
      <div className="h-7 w-48 rounded-full bg-surface" />
      <div className="h-28 w-full max-w-[520px] rounded-2xl bg-surface" />
      <div className="h-14 w-56 rounded-2xl bg-surface" />
    </div>
  );
}
