"use client";

import Link from "next/link";
import { useEffect, useState, useSyncExternalStore, type ReactNode } from "react";
import { api, type ChallengeStatus } from "@/lib/api";
import { challengeShareText, clock, inviteShareText } from "@/lib/format";
import { hasSavedSession } from "@/lib/supabase";
import { Play } from "@/components/icons";
import { SharePanel } from "@/components/share-panel";
import { TikoSays } from "@/components/tiko";
import { Avatar, Card, Spinner } from "@/components/ui";

const noSubscribe = () => () => {};

// The challenge page is written for friends ("X challenged you"). When the
// challenger opens their own link, it shows their side instead: who has
// played, who won, and their own turn.
export function ViewerSwitch({ children }: { children: ReactNode }) {
  // Only a browser that has played before can be the challenger, so
  // first-time visitors never wait on the check (or get a guest account).
  const returning = useSyncExternalStore(noSubscribe, hasSavedSession, () => false);
  // undefined while checking, null when this isn't the challenger
  const [status, setStatus] = useState<ChallengeStatus | null | undefined>(undefined);

  useEffect(() => {
    if (!returning) return;
    // Read in the browser only, so the page can still prerender.
    const code = decodeURIComponent(window.location.pathname.split("/")[2] ?? "");
    let active = true;
    let timer: number | undefined;
    const load = () =>
      api.challengeStatus(code).then(
        (s) => {
          if (!active) return;
          setStatus(s);
          // Keep the challenger's view fresh as friends play.
          if (s && timer === undefined) timer = window.setInterval(load, 10_000);
        },
        () => active && setStatus((prev) => prev ?? null),
      );
    load();
    return () => {
      active = false;
      if (timer !== undefined) clearInterval(timer);
      setStatus(undefined);
    };
  }, [returning]);

  if (!returning || status === null) return children;
  if (status === undefined) {
    return (
      <div className="w-full">
        <Spinner label="Opening your challenge" />
      </div>
    );
  }
  return <OwnerView status={status} />;
}

function OwnerView({ status }: { status: ChallengeStatus }) {
  const { me, friends } = status;
  const title =
    friends.length === 0
      ? "Waiting for your friend"
      : friends.length === 1
        ? `${friends[0].name} is in`
        : `${friends.length} friends are in`;
  const shareText = me.finished
    ? challengeShareText(me.name, me.correct, me.total_ms, status.code)
    : inviteShareText(me.name, status.code);

  return (
    <div className="flex w-full max-w-[640px] flex-col gap-5">
      <span className="flex items-center gap-2 self-start rounded-full bg-orange-tint px-3 py-1.5 text-[13px] font-bold text-orange">
        Your challenge · <span className="font-mono">{status.code}</span>
      </span>
      <h1 className="font-display text-[clamp(28px,4vw,46px)] leading-[1.1] font-bold tracking-tight">{title}</h1>
      <p className="max-w-[520px] text-lg leading-relaxed text-muted">
        {me.finished
          ? `You scored ${me.correct}/5 in ${clock(me.total_ms)}. Everyone who opens this link races your run.`
          : "You haven't played your turn yet. Play now or after your friend: whoever goes second races the other's run."}
      </p>

      {status.open ? (
        <>
          {!me.finished && (
            <Link
              href={`/duel/${status.duel_id}`}
              className="pressable flex min-h-[56px] items-center justify-center gap-2.5 self-start rounded-2xl bg-lime px-7 text-[17px] font-bold text-ink [--pop:#5f7710] hover:bg-lime-hover hover:text-ink"
            >
              <Play />
              Play your turn
            </Link>
          )}
          <div className="max-w-[520px]">
            <SharePanel code={status.code} text={shareText} />
          </div>
        </>
      ) : (
        <p className="max-w-[520px] rounded-2xl border border-line bg-surface p-4 text-sm text-muted">
          This link has expired, so new friends can&apos;t join.{" "}
          <Link href="/" className="font-semibold">
            Start a new challenge
          </Link>
        </p>
      )}

      <Card className="flex max-w-[520px] flex-col p-4">
        <h2 className="px-1 pb-2 text-[15px] font-bold">Friends</h2>
        {friends.length === 0 ? (
          <TikoSays mood="sleep" size={64}>
            Nobody has opened your link yet. It stays open for 7 days.
          </TikoSays>
        ) : (
          <ul className="flex flex-col">
            {friends.map((f) => (
              <FriendRow
                key={f.duel_id}
                friend={f}
                me={me}
                // Before you've played, every row leads to your own turn.
                href={me.finished ? `/duel/${f.duel_id}/result` : `/duel/${status.duel_id}`}
              />
            ))}
          </ul>
        )}
      </Card>

      <Link href="/" className="self-start text-sm font-semibold text-lime hover:text-lime-hover">
        Back to home
      </Link>
    </div>
  );
}

function FriendRow({
  friend: f,
  me,
  href,
}: {
  friend: ChallengeStatus["friends"][number];
  me: ChallengeStatus["me"];
  href: string;
}) {
  let chip = { text: "Playing now", tone: "bg-raised text-muted" };
  if (f.finished && !me.finished) {
    chip = { text: `Done · ${f.correct}/5 in ${clock(f.total_ms)}`, tone: "bg-raised text-soft" };
  } else if (f.finished) {
    const tie = f.score === me.score && f.total_ms === me.total_ms;
    const won = me.score > f.score || (me.score === f.score && me.total_ms < f.total_ms);
    chip = tie
      ? { text: "Tie", tone: "bg-raised text-soft" }
      : won
        ? { text: "You won", tone: "bg-lime-tint text-lime" }
        : { text: `${f.name.split(" ")[0]} won`, tone: "bg-red-tint text-red-soft" };
  }
  return (
    <li className="border-t border-line first:border-t-0">
      <Link href={href} className="flex items-center gap-3 px-1 py-3 text-text hover:text-text">
        <Avatar name={f.name} size={36} />
        <span className="flex min-w-0 flex-1 flex-col">
          <span className="truncate text-sm font-semibold">{f.name}</span>
          {f.college && <span className="truncate text-xs text-muted">{f.college}</span>}
        </span>
        <span className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-bold ${chip.tone}`}>{chip.text}</span>
      </Link>
    </li>
  );
}
