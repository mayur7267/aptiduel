"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { use, useEffect, useState } from "react";
import { account } from "@/lib/account";
import { api, type Profile } from "@/lib/api";
import { batch, tierFor } from "@/lib/format";
import { Close, Flame, Swords, Trophy } from "@/components/icons";
import { DuelSignIn } from "@/components/sign-in-form";
import { Tiko } from "@/components/tiko";
import { Avatar, Card, ErrorNote, PlayerAvatar, Spinner, TierBadge } from "@/components/ui";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// Anyone's profile, as other players see it: who they are, how they play,
// and your own record against them.
export function PublicProfile({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const [profile, setProfile] = useState<Profile | null | undefined>(undefined);
  const [error, setError] = useState<string | null>(null);
  const [signIn, setSignIn] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let active = true;
    api.getProfile(id).then(
      (p) => active && setProfile(p),
      (e: Error) => active && setError(e.message),
    );
    return () => {
      active = false;
    };
  }, [id]);

  // A live room to send them: friend duels need an account first.
  async function duel() {
    setBusy(true);
    setError(null);
    try {
      if ((await account.get()).guest) {
        setSignIn(true);
        setBusy(false);
        return;
      }
      const { code } = await api.createRoom();
      router.push(`/c/${code}`);
    } catch (e) {
      setError((e as Error).message);
      setBusy(false);
    }
  }

  if (error && !profile) return <ErrorNote message={error} onRetry={() => location.reload()} />;
  if (profile === undefined) return <Spinner label="Loading player" />;
  if (profile === null) {
    return (
      <div className="flex flex-col items-center gap-4 pt-12 text-center">
        <Tiko mood="confused" size={84} />
        <h1 className="font-display text-2xl font-bold">Player not found</h1>
        <p className="text-sm text-muted">They may have deleted their account.</p>
        <Link href="/leaderboard" className="font-semibold">See the leaderboard</Link>
      </div>
    );
  }

  const p = profile;
  const tier = tierFor(p.rating);
  const winRate = p.games_played ? Math.round((p.wins / p.games_played) * 100) : null;
  const joined = new Date(p.joined);
  // A guest is "Player 1234": the whole name, not just "Player".
  const first = /^Player \d{4}$/.test(p.name) ? p.name : p.name.split(" ")[0];

  return (
    <div className="flex flex-col gap-4">
      <div className="flex">
        <button
          onClick={() => (history.length > 1 ? router.back() : router.push("/"))}
          aria-label="Back"
          className="flex size-11 items-center justify-center rounded-full border border-line bg-surface hover:bg-raised"
        >
          <Close size={18} strokeWidth={2.2} />
        </button>
      </div>

      <Card className="relative flex flex-col items-center gap-3 overflow-hidden p-6 text-center">
        <span className="absolute inset-x-0 top-0 h-24 bg-[radial-gradient(300px_120px_at_50%_0%,rgba(200,241,53,0.16),transparent)]" />
        <PlayerAvatar name={p.name} bot={p.is_bot} size={84} ring="border-[3px] border-lime" />
        <div className="flex flex-col gap-1">
          <h1 className="font-display text-2xl font-bold">{p.name}</h1>
          <p className="text-sm text-muted">
            {p.is_bot
              ? (p.tagline ?? "Practice bot")
              : [p.college, batch(p.grad_year)].filter(Boolean).join(" · ") || "No college added yet"}
          </p>
        </div>
        <TierBadge rating={p.rating} showRating />
        <div className="flex flex-wrap justify-center gap-x-4 gap-y-1 text-[13px] text-muted">
          {p.college_rank && <span>#{p.college_rank} in their college</span>}
          {tier.next && <span>{tier.next.min - p.rating} to {tier.next.name}</span>}
          {!p.is_bot && <span>Playing since {MONTHS[joined.getMonth()]} {joined.getFullYear()}</span>}
        </div>
      </Card>

      <div className="grid grid-cols-4 gap-2.5">
        {[
          ["Duels", String(p.games_played)],
          ["Wins", String(p.wins)],
          ["Win rate", winRate === null ? "—" : `${winRate}%`],
          ["Best streak", `${p.streak_best}d`],
        ].map(([label, value]) => (
          <div key={label} className="flex flex-col items-center gap-0.5 rounded-2xl border border-line bg-surface px-1 py-3">
            <span className="font-mono text-lg font-bold">{value}</span>
            <span className="text-[11px] font-semibold text-muted">{label}</span>
          </div>
        ))}
      </div>

      <Card className="flex flex-col gap-3 p-4">
        <div className="flex items-center justify-between">
          <h2 className="font-display text-base font-bold">Recent form</h2>
          {p.streak > 0 && (
            <span className="flex items-center gap-1 text-xs font-bold text-orange">
              <Flame size={14} />
              {p.streak}-day streak
            </span>
          )}
        </div>
        {p.recent.length ? (
          <ol className="flex flex-wrap gap-1.5" aria-label="Last duels, oldest first">
            {[...p.recent].reverse().map((r, i) => (
              <li
                key={i}
                className={`flex size-8 items-center justify-center rounded-lg font-mono text-sm font-bold ${
                  r === "W" ? "bg-lime text-ink" : r === "L" ? "bg-red-tint text-red-soft" : "bg-raised text-soft"
                }`}
              >
                {r}
              </li>
            ))}
          </ol>
        ) : (
          <p className="text-sm text-muted">No finished duels yet.</p>
        )}
      </Card>

      {p.vs_me && (
        <Card className="flex items-center gap-4 p-4">
          <Trophy size={22} className="shrink-0 text-lime" />
          <div className="flex min-w-0 flex-1 flex-col">
            <span className="text-sm font-semibold">You vs {first}</span>
            <span className="text-xs text-muted">
              {p.vs_me.played
                ? `${p.vs_me.played} ${p.vs_me.played === 1 ? "duel" : "duels"} played`
                : `You haven't played ${first} yet.`}
            </span>
          </div>
          {p.vs_me.played > 0 && (
            <span className="font-mono text-2xl font-bold">
              <span className="text-lime">{p.vs_me.wins}</span>
              <span className="text-faint"> – </span>
              <span className="text-orange">{p.vs_me.losses}</span>
            </span>
          )}
        </Card>
      )}

      {p.is_me ? (
        <Link href="/profile" className="flex items-center gap-3 rounded-2xl border border-line bg-surface p-4 hover:bg-raised">
          <Avatar name={p.name} size={36} />
          <span className="flex-1 text-sm">
            <span className="font-semibold">This is how others see you</span>
            <span className="block text-muted">Edit your name and college on your profile.</span>
          </span>
        </Link>
      ) : p.is_bot ? (
        <Link
          href="/play"
          className="flex h-14 items-center justify-center gap-2.5 rounded-2xl bg-lime text-base font-bold text-ink hover:bg-lime-hover hover:text-ink"
        >
          <Swords size={20} />
          Quick Match
        </Link>
      ) : (
        <button
          onClick={duel}
          disabled={busy}
          className="pressable flex h-14 items-center justify-center gap-2.5 rounded-2xl bg-orange text-base font-bold text-ink [--pop:#6b3415] disabled:opacity-70"
        >
          <Swords size={20} />
          {busy ? "Opening a room…" : `Duel ${first} live`}
        </button>
      )}
      {error && <ErrorNote message={error} />}
      <DuelSignIn open={signIn} onClose={() => setSignIn(false)} onDone={() => { setSignIn(false); duel(); }} />
    </div>
  );
}
