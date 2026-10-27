"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api, type Duel, type Me, type Player } from "@/lib/api";
import type { Company } from "@/lib/companies";
import { tierFor } from "@/lib/format";
import { Close } from "@/components/icons";
import { BotTag, ErrorNote, PlayerAvatar } from "@/components/ui";

const STATUS = ["Looking for players near your rating", "Checking recent runs", "Lining up a fair match"];
const companyStatus = (c: Company) => [`Picking ${c.name} pattern questions`, "Finding a bot near your rating", "Lining up a fair match"];

// Quick Match lobby: a short radar search, then the opponent reveal and
// a 3-2-1 countdown into the duel. With a company, the questions all come
// from that company's test pattern.
export function Matchmaking({ company = null }: { company?: Company | null }) {
  const router = useRouter();
  const [me, setMe] = useState<Me | null>(null);
  const [duel, setDuel] = useState<Duel | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState(0);
  const [count, setCount] = useState(3);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let active = true;
    // A short, varied search so a match feels found rather than instant.
    const minWait = new Promise((r) => setTimeout(r, 1800 + Math.random() * 1500));
    api
      .getMe()
      .then((m) => active && setMe(m))
      .catch(() => {});
    const find = company ? api.companyMatch(company.name) : api.quickMatch();
    Promise.all([find.then(({ duel_id }) => api.getDuel(duel_id)), minWait])
      .then(([d]) => active && setDuel(d))
      .catch((e: Error) => active && setError(e.message));
    const ticker = setInterval(() => setStatus((s) => (s + 1) % STATUS.length), 1100);
    return () => {
      active = false;
      clearInterval(ticker);
      // Next keeps this screen mounted (hidden) once the duel opens, so
      // reset it for the next search.
      setDuel(null);
      setError(null);
      setCount(3);
      setStatus(0);
    };
  }, [attempt, company]);

  useEffect(() => {
    if (!duel) return;
    const t = setTimeout(() => {
      if (count <= 1) router.replace(`/duel/${duel.id}`);
      else setCount((c) => c - 1);
    }, 900);
    return () => clearTimeout(t);
  }, [duel, count, router]);

  return (
    <main className="relative flex min-h-dvh flex-1 flex-col items-center overflow-hidden bg-[radial-gradient(560px_420px_at_50%_38%,rgba(200,241,53,0.09),transparent)] px-4 pt-5 pb-10">
      <div className="flex w-full max-w-xl items-center justify-between">
        <Link
          href="/"
          aria-label="Cancel and go home"
          className="flex size-11 items-center justify-center rounded-full border border-line bg-surface text-text hover:bg-raised hover:text-text"
        >
          <Close size={18} strokeWidth={2.2} />
        </Link>
        <span className="text-sm font-semibold text-muted">{company ? `${company.name} practice` : "Quick Match"}</span>
        <span className="size-11" />
      </div>

      <div className="flex w-full max-w-xl flex-1 flex-col items-center justify-center gap-9">
        {error ? (
          <div className="flex w-full flex-col gap-3">
            <ErrorNote message={error} onRetry={() => setAttempt((n) => n + 1)} />
            <Link href="/" className="text-sm font-semibold text-lime hover:text-lime-hover">
              Back to home
            </Link>
          </div>
        ) : duel ? (
          <Reveal me={duel.me} opponent={duel.opponent} count={count} resuming={duel.me.answered > 0} />
        ) : (
          <Searching me={me} status={(company ? companyStatus(company) : STATUS)[status]} />
        )}
      </div>
    </main>
  );
}

function Searching({ me, status }: { me: Me | null; status: string }) {
  return (
    <>
      <div aria-hidden="true" className="relative flex size-[280px] items-center justify-center sm:size-[340px]">
        {[0, 0.8, 1.6].map((delay) => (
          <span
            key={delay}
            className="absolute inset-0 rounded-full border-2 border-lime/40 motion-safe:animate-radar motion-reduce:opacity-30"
            style={{ animationDelay: `${delay}s` }}
          />
        ))}
        <span className="absolute inset-[14%] rounded-full border border-line" />
        <span className="absolute inset-[30%] rounded-full border border-line" />
        <span className="absolute inset-0 rounded-full bg-[conic-gradient(from_0deg,rgba(200,241,53,0.28),transparent_22%)] motion-safe:animate-sweep" />
        <span className="absolute inset-[6%] motion-safe:animate-orbit">
          <span className="absolute top-0 left-1/2 size-3 -translate-x-1/2 rounded-full bg-orange shadow-[0_0_14px_#ff8a4c]" />
          <span className="absolute bottom-[14%] left-[6%] size-2.5 rounded-full bg-violet shadow-[0_0_14px_#a594ff]" />
        </span>
        <span className="absolute inset-[22%] motion-safe:animate-orbit-reverse">
          <span className="absolute top-[8%] right-[4%] size-2.5 rounded-full bg-[#5ce1e6] shadow-[0_0_14px_#5ce1e6]" />
        </span>
        <span className="relative rounded-full ring-4 ring-lime ring-offset-4 ring-offset-ink">
          <PlayerAvatar name={me?.name ?? "You"} bot={false} size={92} />
        </span>
      </div>

      <div className="flex flex-col items-center gap-2 text-center">
        <h1 role="status" className="font-display text-2xl font-bold">
          Finding an opponent
          <span aria-hidden="true" className="ml-1 inline-flex gap-1">
            {[0, 150, 300].map((d) => (
              <span
                key={d}
                className="inline-block size-1.5 rounded-full bg-lime motion-safe:animate-dot"
                style={{ animationDelay: `${d}ms` }}
              />
            ))}
          </span>
        </h1>
        <p className="text-sm text-muted">
          {status}
          {me && ` · ${me.rating.toLocaleString("en-IN")}`}
        </p>
      </div>

      <Link
        href="/"
        className="rounded-xl border border-line px-5 py-2.5 text-sm font-semibold text-muted hover:bg-surface hover:text-text"
      >
        Cancel
      </Link>
    </>
  );
}

function Reveal({
  me,
  opponent,
  count,
  resuming,
}: {
  me: Player;
  opponent: Player | null;
  count: number;
  resuming: boolean;
}) {
  return (
    <>
      <p className="text-xs font-bold tracking-[0.24em] text-lime uppercase motion-safe:animate-pop">
        {resuming ? "Finish your match" : opponent ? "Opponent found" : "Ready"}
      </p>

      <div className="grid w-full grid-cols-[1fr_auto_1fr] items-start gap-2 sm:gap-4">
        <div className="motion-safe:animate-enter-left">
          <Side player={me} label="You" ring="ring-lime" />
        </div>
        <span
          className="mt-8 font-display text-3xl font-bold text-lime motion-safe:animate-pop sm:text-4xl"
          style={{ animationDelay: "250ms" }}
        >
          VS
        </span>
        <div className="motion-safe:animate-enter-right">
          {opponent ? (
            <Side player={opponent} ring="ring-orange" />
          ) : (
            <div className="flex flex-col items-center gap-2 text-center">
              <span className="flex size-[84px] items-center justify-center rounded-full border-2 border-dashed border-line-strong text-2xl text-muted">
                ?
              </span>
              <span className="font-semibold">Solo run</span>
            </div>
          )}
        </div>
      </div>

      {opponent?.tagline && <p className="max-w-xs text-center text-sm text-muted italic">“{opponent.tagline}”</p>}

      <div className="flex flex-col items-center gap-1" aria-live="polite">
        <span className="text-xs font-semibold tracking-wider text-muted uppercase">Starting in</span>
        <span key={count} className="font-display text-6xl font-bold motion-safe:animate-pop">
          {count}
        </span>
      </div>
    </>
  );
}

function Side({ player, label, ring }: { player: Player; label?: string; ring: string }) {
  return (
    <div className="flex min-w-0 flex-col items-center gap-2 text-center">
      <span className={`rounded-full ring-4 ring-offset-4 ring-offset-ink ${ring}`}>
        <PlayerAvatar name={player.name} bot={player.is_bot} size={84} />
      </span>
      <span className="mt-1 max-w-full truncate text-[15px] font-bold">
        {label ?? player.name}
        {player.is_bot && <BotTag />}
      </span>
      <span className="text-xs text-muted">
        <span className="font-mono">{player.rating.toLocaleString("en-IN")}</span> · {tierFor(player.rating).name}
      </span>
      {!player.is_bot && player.college && !label && (
        <span className="max-w-full truncate text-xs text-faint">{player.college}</span>
      )}
    </div>
  );
}
