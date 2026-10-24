import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { getChallenge } from "@/lib/challenge";
import { clock } from "@/lib/format";
import { Bolt, Check } from "@/components/icons";
import { Avatar, Logo, TierBadge } from "@/components/ui";
import { AcceptButton } from "./accept-button";

export async function generateMetadata({ params }: PageProps<"/c/[code]">): Promise<Metadata> {
  const { code } = await params;
  const ch = await getChallenge(code);
  if (!ch) return { title: "Challenge not found" };
  const title = `${ch.challenger.name} challenged you to an aptitude duel`;
  const description = ch.challenger_finished
    ? `Score to beat: ${ch.correct}/5 in ${clock(ch.total_ms)}. 5 placement-style questions, about 3 minutes. No sign-up.`
    : "5 placement-style questions, about 3 minutes. No sign-up.";
  return { title, description, openGraph: { title, description }, robots: { index: false } };
}

export default function ChallengePage({ params }: PageProps<"/c/[code]">) {
  return (
    <div className="flex min-h-full flex-1 flex-col">
      <header className="border-b border-[#1c2232]">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-4 sm:px-6">
          <Logo />
          <Link href="/" className="rounded-xl border border-line bg-surface px-4 py-2.5 text-sm font-semibold text-text hover:bg-raised">
            Start your own
          </Link>
        </div>
      </header>

      <main className="flex-1">
        <section className="mx-auto flex max-w-6xl flex-wrap items-center gap-12 px-4 py-12 sm:px-6 sm:py-16">
          <div className="flex min-w-0 flex-[1_1_480px] flex-col gap-5">
            <Suspense fallback={<ChallengeSkeleton />}>
              <ChallengeIntro params={params} />
            </Suspense>
          </div>
          <div className="flex min-w-0 flex-[1_1_360px] justify-center">
            <DuelPreview />
          </div>
        </section>

        <section className="border-t border-[#1c2232] bg-[#0e121c]">
          <div className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-14 sm:px-6">
            <h2 className="font-display text-2xl font-bold sm:text-3xl">How a duel works</h2>
            <div className="grid gap-4 sm:grid-cols-3">
              {[
                ["01", "Same 5 questions", "You get exactly the questions your friend played. Up to a minute each."],
                ["02", "Beat the score", "100 points for every correct answer, plus up to 50 for speed."],
                ["03", "Earn your rating", "Win to climb from Fresher to Architect, and put your college on the board."],
              ].map(([n, title, body]) => (
                <div key={n} className="flex flex-col gap-2.5 rounded-[20px] border border-line bg-surface p-5">
                  <span className="font-display text-2xl font-bold text-lime">{n}</span>
                  <span className="text-[17px] font-bold">{title}</span>
                  <span className="text-[15px] leading-relaxed text-muted">{body}</span>
                </div>
              ))}
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t border-[#1c2232]">
        <div className="mx-auto max-w-6xl px-4 py-6 text-[13px] text-faint sm:px-6">
          © 2026 AptiDuel · Questions are original, written in the style of placement aptitude tests.
        </div>
      </footer>
    </div>
  );
}

async function ChallengeIntro({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  const ch = await getChallenge(code);
  if (!ch) notFound();
  const { challenger } = ch;

  return (
    <>
      <span className="flex items-center gap-2 self-start rounded-full bg-lime-tint px-3 py-1.5 text-[13px] font-bold text-lime">
        <Bolt size={14} strokeWidth={2.6} />
        You&apos;ve been challenged
      </span>
      <h1 className="font-display text-[clamp(30px,4.6vw,54px)] leading-[1.08] font-bold tracking-tight">
        {challenger.name} challenged you to an aptitude duel.
      </h1>
      <p className="max-w-[520px] text-lg leading-relaxed text-muted">
        5 placement-style questions. About 3 minutes. No sign-up, no download. Just tap play.
      </p>

      <div className="sticker flex max-w-[520px] flex-wrap items-center gap-4 rounded-[20px] border-2 border-line bg-surface p-4">
        <Avatar name={challenger.name} size={52} ring="border-2 border-violet" />
        <div className="flex min-w-[160px] flex-1 flex-col gap-1">
          <span className="font-bold">{challenger.name}</span>
          {challenger.college && (
            <span className="text-[13px] text-muted">
              {challenger.college}
              {challenger.grad_year ? ` · ’${String(challenger.grad_year).slice(2)}` : ""}
            </span>
          )}
          <span className="mt-0.5">
            <TierBadge rating={challenger.rating} showRating />
          </span>
        </div>
        {ch.challenger_finished && (
          <div className="flex flex-col items-end">
            <span className="text-xs text-muted">Score to beat</span>
            <span className="font-mono text-2xl font-bold">{ch.correct}/5</span>
            <span className="font-mono text-xs text-muted">in {clock(ch.total_ms)}</span>
          </div>
        )}
      </div>

      {ch.open ? (
        <AcceptButton code={ch.code} />
      ) : (
        <p className="rounded-2xl border border-line bg-surface p-4 text-sm text-muted">
          This challenge has expired.{" "}
          <Link href="/" className="font-semibold">Start a new one</Link>
        </p>
      )}

      <div className="flex flex-wrap gap-x-5 gap-y-2 text-[13px] text-muted">
        {["Free", "Works in any browser", "Quant, reasoning, verbal"].map((t) => (
          <span key={t} className="flex items-center gap-1.5">
            <Check size={14} strokeWidth={3} className="text-lime" />
            {t}
          </span>
        ))}
        {ch.accepted_count > 0 && <span>{ch.accepted_count} already played</span>}
      </div>
    </>
  );
}

function ChallengeSkeleton() {
  return (
    <div aria-hidden="true" className="flex animate-pulse flex-col gap-5">
      <div className="h-7 w-48 rounded-full bg-surface" />
      <div className="h-28 w-full max-w-[520px] rounded-2xl bg-surface" />
      <div className="h-24 w-full max-w-[520px] rounded-[20px] bg-surface" />
      <div className="h-14 w-56 rounded-2xl bg-surface" />
    </div>
  );
}

// A static picture of the duel screen, so first-time visitors know what
// they are about to play.
function DuelPreview() {
  const options = ["20%", "25%", "16%", "30%"];
  return (
    <div aria-hidden="true" className="sticker flex w-full max-w-[420px] rotate-1 flex-col gap-4 rounded-[28px] border-2 border-line bg-surface p-5 [--pop:#5f7710]">
      <div className="flex items-center justify-between text-sm font-semibold">
        <span>Question 1 of 5</span>
        <span className="rounded-full bg-ink px-2.5 py-1 tabular-nums">0:40</span>
      </div>
      <div className="h-1.5 rounded-full bg-lime" />
      <p className="text-[17px] leading-relaxed font-semibold">
        The cost price of 20 articles equals the selling price of 16. What is the profit percentage?
      </p>
      <div className="grid grid-cols-2 gap-2.5">
        {options.map((o, i) => (
          <div
            key={o}
            className={`flex min-h-[52px] items-center gap-2.5 rounded-[14px] border px-3.5 font-semibold ${
              i === 1 ? "border-lime bg-lime-tint" : "border-[#2d3548] bg-raised"
            }`}
          >
            <span
              className={`flex size-[26px] items-center justify-center rounded-lg text-xs font-bold ${
                i === 1 ? "bg-lime text-ink" : "bg-line text-muted"
              }`}
            >
              {"ABCD"[i]}
            </span>
            {o}
          </div>
        ))}
      </div>
    </div>
  );
}
