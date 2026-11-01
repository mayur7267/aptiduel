"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState, useSyncExternalStore } from "react";
import { account } from "@/lib/account";
import { api, type Challenge } from "@/lib/api";
import { liveInviteText } from "@/lib/format";
import { useLiveState } from "@/lib/live";
import { hasSavedSession } from "@/lib/supabase";
import { Bolt, Check, Play } from "@/components/icons";
import { SharePanel } from "@/components/share-panel";
import { DuelSignIn } from "@/components/sign-in-form";
import { Tiko } from "@/components/tiko";
import { Avatar, ErrorNote, Spinner, TierBadge } from "@/components/ui";

const noSubscribe = () => () => {};
const primary =
  "pressable flex min-h-[58px] items-center justify-center gap-2.5 self-start rounded-2xl bg-lime px-7 text-[17px] font-bold text-ink [--pop:#5f7710] hover:bg-lime-hover disabled:opacity-70";
const secondary =
  "flex h-12 items-center justify-center gap-2 self-start rounded-2xl border border-line bg-surface px-5 text-[15px] font-semibold text-text hover:bg-raised hover:text-text disabled:opacity-70";

// How long the host waits before "Play now" is offered.
const OFFER_PLAY_NOW_MS = 45_000;

// A live room's page. Players in it see the lobby; anyone else sees the
// invite, signs in if they're a guest, and joins.
export function LiveRoom({ challenge }: { challenge: Challenge }) {
  const router = useRouter();
  // Only a browser that has played before can already be in the room,
  // so first-time visitors never wait on the check (or get a guest).
  const returning = useSyncExternalStore(noSubscribe, hasSavedSession, () => false);
  const [seat, setSeat] = useState<"checking" | "out" | "in">("checking");
  const [guest, setGuest] = useState(true);
  const [duelId, setDuelId] = useState<string | null>(null);
  const [signIn, setSignIn] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!returning) return;
    let active = true;
    Promise.all([account.get(), api.getChallenge(challenge.code)])
      .then(async ([a, ch]) => {
        if (!active) return;
        setGuest(a.guest);
        if (!ch?.my_seat) return setSeat("out");
        const { duel_id } = await api.joinRoom(challenge.code);
        if (!active) return;
        setDuelId(duel_id);
        setSeat("in");
      })
      .catch(() => active && setSeat("out"));
    return () => {
      active = false;
    };
  }, [returning, challenge.code]);

  async function join() {
    setBusy(true);
    setError(null);
    try {
      const r = await api.joinRoom(challenge.code);
      // Nobody waited: it's an ordinary challenge now, so you play your turn.
      if (r.mode === "challenge") return router.push(`/duel/${r.duel_id}`);
      setDuelId(r.duel_id);
      setSeat("in");
    } catch (e) {
      setError((e as Error).message);
    }
    setBusy(false);
  }

  function signedIn() {
    setSignIn(false);
    setGuest(false);
    join();
  }

  // A first-time visitor is out until they join (after signing in).
  const where = seat === "checking" && !returning ? "out" : seat;
  if (where === "checking") {
    return (
      <div className="w-full">
        <Spinner label="Opening the duel" />
      </div>
    );
  }
  if (where === "in" && duelId) return <Lobby duelId={duelId} challenge={challenge} />;

  const { challenger } = challenge;
  const closed = !challenge.open || challenge.started || challenge.full;
  return (
    <>
      <div className="flex min-w-0 flex-[1_1_480px] flex-col gap-5">
        <span className="flex items-center gap-2 self-start rounded-full bg-orange-tint px-3 py-1.5 text-[13px] font-bold text-orange">
          <span className="size-2 rounded-full bg-orange motion-safe:animate-pulse" />
          Live duel
        </span>
        <h1 className="font-display text-[clamp(30px,4.6vw,54px)] leading-[1.08] font-bold tracking-tight">
          {challenger.name} wants to duel you, live.
        </h1>
        <p className="max-w-[520px] text-lg leading-relaxed text-muted">
          You race through the same 5 placement questions, starting together. Fast and right wins. About 3 minutes.
        </p>

        <ChallengerCard challenge={challenge} />

        {closed ? (
          <p className="max-w-[520px] rounded-2xl border border-line bg-surface p-4 text-sm text-muted">
            {challenge.started || challenge.full
              ? `${challenger.name} is already in a duel with someone else. `
              : "This duel has closed. "}
            <Link href="/" className="font-semibold">Start your own</Link>
          </p>
        ) : guest ? (
          <div className="flex flex-col gap-2.5">
            <button onClick={() => setSignIn(true)} className={primary}>
              <Play />
              Sign in to join
            </button>
            <p className="max-w-[460px] text-sm text-muted">
              Friend duels are between real accounts, so you both know who you&apos;re playing. It takes a code from
              your email, nothing else.
            </p>
          </div>
        ) : (
          <button onClick={join} disabled={busy} className={primary}>
            <Play />
            {busy ? "Joining…" : "Join the duel"}
          </button>
        )}
        {error && <ErrorNote message={error} />}

        <div className="flex flex-wrap gap-x-5 gap-y-2 text-[13px] text-muted">
          {["Free", "Same account on the app and the website", "Quant, reasoning, verbal"].map((t) => (
            <span key={t} className="flex items-center gap-1.5">
              <Check size={14} strokeWidth={3} className="text-lime" />
              {t}
            </span>
          ))}
        </div>
      </div>
      <div className="flex min-w-0 flex-[1_1_360px] justify-center pt-10">
        <Versus left={challenger.name} right={null} />
      </div>
      <DuelSignIn open={signIn} onClose={() => setSignIn(false)} onDone={signedIn} />
    </>
  );
}

function ChallengerCard({ challenge }: { challenge: Challenge }) {
  const { challenger } = challenge;
  return (
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
    </div>
  );
}

// Waiting together. The duel starts by itself once both players are here,
// and the live screen takes over.
function Lobby({ duelId, challenge }: { duelId: string; challenge: Challenge }) {
  const router = useRouter();
  const { state, error } = useLiveState(duelId);
  const [since] = useState(() => Date.now());
  const [now, setNow] = useState(() => Date.now());
  const [busy, setBusy] = useState<"play" | "close" | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);

  const status = state?.status;
  useEffect(() => {
    if (status === "starting" || status === "playing" || status === "done") router.replace(`/live/${duelId}`);
  }, [status, duelId, router]);

  async function playNow() {
    setBusy("play");
    setActionError(null);
    try {
      await api.livePlayNow(duelId);
      router.push(`/duel/${duelId}`);
    } catch (e) {
      setActionError((e as Error).message);
      setBusy(null);
    }
  }

  async function close() {
    setBusy("close");
    try {
      await api.liveCancel(duelId);
    } catch {
      // Leaving anyway; an unused room just closes after a week.
    }
    router.push("/");
  }

  if (!state) {
    return error ? <ErrorNote message={error} onRetry={() => location.reload()} /> : <Spinner label="Opening the lobby" />;
  }

  const opp = state.opponent;
  const host = state.is_host;
  const waitedLong = now - since > OFFER_PLAY_NOW_MS;
  const elapsed = Math.floor((now - since) / 1000);
  const other = host ? "your friend" : challenge.challenger.name;

  let title: string;
  let line: string;
  if (state.status === "async") {
    title = "It's a recorded challenge now";
    line = `${opp?.name ?? other} couldn't wait, so they played their turn. Play yours whenever you like: you'll race their run.`;
  } else if (state.status === "closed") {
    title = "This duel was closed";
    line = "Start a new one from home and send a fresh link.";
  } else if (!opp) {
    title = "Waiting for your friend";
    line = "Send them the link. The duel starts the moment they join.";
  } else if (!opp.present) {
    title = `Waiting for ${opp.name}`;
    line = host
      ? `${opp.name} joined but stepped away. You'll start as soon as they're back.`
      : `${opp.name} isn't here right now. You'll start as soon as they open the duel.`;
  } else {
    title = `${opp.name} is here!`;
    line = "Get ready…";
  }

  return (
    <>
      <div className="flex min-w-0 flex-[1_1_480px] flex-col gap-5" aria-live="polite">
        <span className="flex items-center gap-2 self-start rounded-full bg-orange-tint px-3 py-1.5 text-[13px] font-bold text-orange">
          <span className="size-2 rounded-full bg-orange motion-safe:animate-pulse" />
          Live duel · room {state.code}
        </span>
        <h1 className="font-display text-[clamp(28px,4.2vw,48px)] leading-[1.08] font-bold tracking-tight">{title}</h1>
        <p className="max-w-[520px] text-lg leading-relaxed text-muted">{line}</p>

        {state.status === "async" ? (
          <Link href={`/duel/${duelId}`} className={primary}>
            <Play />
            Play your turn
          </Link>
        ) : state.status === "closed" ? (
          <Link href="/" className={primary}>
            Back to home
          </Link>
        ) : (
          <>
            {host && !opp && (
              <div className="flex max-w-[520px] flex-col gap-2.5">
                <SharePanel code={state.code} text={liveInviteText(state.me.name, state.code)} />
                <p className="text-sm text-muted">
                  Or tell them the room code: <span className="font-mono font-bold tracking-[0.2em] text-text">{state.code}</span>
                </p>
              </div>
            )}
            <p className="flex items-center gap-2 font-mono text-sm text-faint">
              <span className="flex gap-0.5" aria-hidden="true">
                {[0, 150, 300].map((d) => (
                  <span key={d} className="size-1.5 rounded-full bg-orange motion-safe:animate-dot" style={{ animationDelay: `${d}ms` }} />
                ))}
              </span>
              Waiting {Math.floor(elapsed / 60)}:{String(elapsed % 60).padStart(2, "0")}
            </p>

            {/* Nobody has to wait forever: play now, and the other side races your run later. */}
            {(waitedLong || (opp && !opp.present && !host)) && (
              <div className="flex max-w-[520px] flex-col gap-2 rounded-2xl border border-line bg-surface p-4">
                <span className="text-sm font-semibold">Can&apos;t wait?</span>
                <span className="text-sm text-muted">
                  Play now and {opp?.name ?? other} races your run when they open the link. It counts the same.
                </span>
                <button onClick={playNow} disabled={busy !== null} className={`${secondary} mt-1`}>
                  <Bolt size={18} strokeWidth={2.4} />
                  {busy === "play" ? "Starting…" : "Play now"}
                </button>
              </div>
            )}
            {host && (
              <button onClick={close} disabled={busy !== null} className="self-start text-sm text-muted underline">
                {busy === "close" ? "Closing…" : "Close this room"}
              </button>
            )}
          </>
        )}
        {(actionError || error) && <ErrorNote message={(actionError ?? error)!} />}
      </div>
      <div className="flex min-w-0 flex-[1_1_360px] justify-center pt-10">
        <Versus left={state.me.name} right={opp?.present ? opp.name : null} you />
      </div>
    </>
  );
}

// You (or the host) against the friend, who is a question mark until they
// arrive.
function Versus({ left, right, you = false }: { left: string; right: string | null; you?: boolean }) {
  return (
    <div className="relative w-full max-w-[420px]">
      <Tiko mood={right ? "cheer" : "think"} size={84} className="absolute -top-[72px] right-4 z-10" />
      <div className="sticker grid grid-cols-[1fr_auto_1fr] items-center gap-3 rounded-[28px] border-2 border-line bg-surface p-6 [--pop:#4a2612]">
        <Seat name={left} label={you ? "You" : "Host"} />
        <span className="-rotate-6 rounded-md bg-raised px-2.5 py-1.5 font-display text-sm font-bold text-soft">VS</span>
        {right ? (
          <Seat name={right} label={you ? "Friend" : "You"} />
        ) : (
          <div className="flex flex-col items-center gap-2 text-center">
            <span className="flex size-16 items-center justify-center rounded-full border-2 border-dashed border-line-strong font-display text-2xl text-faint motion-safe:animate-pulse">
              ?
            </span>
            <span className="text-xs font-semibold text-faint">Waiting…</span>
          </div>
        )}
      </div>
    </div>
  );
}

function Seat({ name, label }: { name: string; label: string }) {
  return (
    <div className="flex min-w-0 flex-col items-center gap-2 text-center">
      <Avatar name={name} size={64} ring="border-2 border-line-strong" />
      <span className="max-w-full truncate text-sm font-bold">{name}</span>
      <span className="font-mono text-[10px] font-bold tracking-wider text-faint uppercase">{label}</span>
    </div>
  );
}

