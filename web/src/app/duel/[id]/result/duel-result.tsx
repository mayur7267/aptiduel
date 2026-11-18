"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { use, useEffect, useEffectEvent, useState, type FormEvent } from "react";
import { api, type Duel, type Me, type Player, type ReviewItem, type ShareChannel, type ShareKind } from "@/lib/api";
import { COMPANIES } from "@/lib/companies";
import { openFeedback } from "@/lib/feedback";
import { challengeShareText, clock, dailyShareText, shortDay, signed, tierFor } from "@/lib/format";
import { Bolt, Check, Close, Refresh, Shield, Trophy } from "@/components/icons";
import { Figure } from "@/components/figure";
import { Tiko, type TikoMood } from "@/components/tiko";
import { SharePanel } from "@/components/share-panel";
import { StoryButton, type StoryData } from "@/components/story-card";
import { BotTag, Card, ErrorNote, PlayerAvatar, Spinner } from "@/components/ui";

export function DuelResult({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const [duel, setDuel] = useState<Duel | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [ownCode, setOwnCode] = useState<string | null>(null);
  const [busy, setBusy] = useState<"share" | "rematch" | null>(null);
  // A live duel's rematch room, once either player has asked for one.
  const [rematchId, setRematchId] = useState<string | null>(null);
  const [showReview, setShowReview] = useState(false);
  // Your profile: the streak for the Daily share, and your college and
  // year so saving a name here doesn't clear them.
  const [profile, setProfile] = useState<Me | null>(null);
  // Set once a story picture went to the share sheet: its link was copied.
  const [storyShared, setStoryShared] = useState(false);

  useEffect(() => {
    api.getMe().then(setProfile, () => {});
  }, []);

  const onLoaded = useEffectEvent((d: Duel) => {
    if (d.me.finished) setDuel(d);
    else router.replace(`/duel/${id}`);
  });

  useEffect(() => {
    let active = true;
    api
      .getDuel(id)
      .then((d) => active && onLoaded(d))
      .catch((e: Error) => active && setError(e.message));
    return () => {
      active = false;
    };
  }, [id]);

  // Next keeps this page mounted (hidden) after navigating away. Clear the
  // busy flag when it hides so Back doesn't show a stuck "Starting…".
  useEffect(() => () => setBusy(null), []);

  // Keep checking while an opponent can still arrive or finish: a friend
  // accepting your challenge, or a live opponent still playing. Daily and
  // solo runs never get one, so they don't poll.
  const waiting =
    duel !== null &&
    (duel.mode === "challenge"
      ? duel.opponent?.finished !== true
      : duel.opponent !== null && !duel.opponent.finished);
  // A live race updates every couple of seconds; others every 8.
  const every = duel?.mode === "live" ? 2000 : 8000;
  useEffect(() => {
    if (!waiting) return;
    const timer = setInterval(() => {
      api.getDuel(id).then(onLoaded).catch(() => {});
    }, every);
    return () => clearInterval(timer);
  }, [id, waiting, every]);

  // Live duels: see when the other player asks for a rematch.
  const live = duel?.mode === "live";
  useEffect(() => {
    if (!live) return;
    const check = () => api.liveState(id).then((s) => setRematchId(s.rematch_id), () => {});
    check();
    const timer = setInterval(check, 2500);
    return () => clearInterval(timer);
  }, [id, live]);

  // Asking again just returns the room the other player made.
  async function rematchLive() {
    setBusy("rematch");
    try {
      const { code } = await api.liveRematch(id);
      router.push(`/c/${code}`);
    } catch (e) {
      setError((e as Error).message);
      setBusy(null);
    }
  }

  async function makeShareCode() {
    setBusy("share");
    try {
      setOwnCode((await api.shareCode(id)).code);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(null);
    }
  }

  if (error && !duel) return <ErrorNote message={error} onRetry={() => location.reload()} />;
  if (!duel) return <Spinner label="Loading result" />;

  const { me, opponent: opp } = duel;
  const shareCode = duel.is_creator ? duel.code : ownCode;
  // After company practice, "play again" means the same company.
  const rematch = COMPANIES.find((c) => c.name === duel.company) ?? null;
  const delta = me.rating_before !== null && me.rating_after !== null && !me.is_replay ? me.rating_after - me.rating_before : null;

  let outcome: Outcome | null = null;
  if (opp?.finished) {
    if (me.score === opp.score && me.total_ms === opp.total_ms) outcome = "draw";
    else outcome = me.score > opp.score || (me.score === opp.score && me.total_ms < opp.total_ms) ? "win" : "loss";
  }

  const grid = duel.review ? [...duel.review].sort((a, b) => a.q_index - b.q_index).map((r) => r.is_correct) : [];
  const logShare = (kind: ShareKind) => (channel: ShareChannel) => {
    api.logShare(kind, channel, duel.id).catch(() => {});
  };
  // Ask for a name only while the profile still has the made-up one
  // ("Player 1586"). Checked on the profile, not this game, so a name saved
  // since counts, and nothing shows until the profile has loaded.
  const guestName = profile !== null && /^Player \d{4}$/.test(profile.name);
  const named = (name: string) => {
    setProfile((p) => (p ? { ...p, name } : p));
    setDuel((d) => (d ? { ...d, me: { ...d.me, name } } : d));
  };
  const story =
    grid.length === 5 ? (
      <StoryButton
        data={storyData(duel, outcome, grid)}
        onShare={(channel) => {
          logShare("story")(channel);
          if (channel === "share") setStoryShared(true);
        }}
      />
    ) : null;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex">
        <Link
          href="/"
          aria-label="Back to home"
          className="flex size-11 items-center justify-center rounded-full border border-line bg-surface hover:bg-raised"
        >
          <Close size={18} strokeWidth={2.2} />
        </Link>
      </div>

      {outcome === "win" && <Confetti />}
      <Hero duel={duel} outcome={outcome} />

      {opp && outcome && <Scoreboard me={me} opp={opp} outcome={outcome} />}

      {delta !== null && me.rating_before !== null && me.rating_after !== null && (
        <RatingCard before={me.rating_before} after={me.rating_after} delta={delta} />
      )}
      {live && delta === 0 && (
        <p className="-mt-2 text-[13px] text-muted">
          Friends move each other&apos;s rating once a day, so this one was just for fun.
        </p>
      )}

      {live && opp?.finished && (
        <button
          onClick={rematchLive}
          disabled={busy !== null}
          className="pressable flex h-14 items-center justify-center gap-2.5 rounded-2xl bg-orange text-base font-bold text-ink [--pop:#6b3415] disabled:opacity-70"
        >
          <Refresh size={20} strokeWidth={2.4} />
          {busy === "rematch" ? "Opening the room…" : rematchId ? `${opp.name} is ready: join the rematch` : `Rematch ${opp.name}`}
        </button>
      )}

      {duel.review && <AnswerDots review={duel.review} />}

      {guestName && <NameForm current={profile.name} profile={profile} onSaved={named} />}

      <section className="mt-1 flex flex-col gap-2.5" aria-label="Share">
        {duel.mode === "daily" ? (
          // The message is a grid that gives nothing away: friends see how
          // you did, never which questions, and the link says who sent it.
          <SharePanel
            code={duel.code}
            path={`/d/${duel.code}`}
            label="Share my Daily on WhatsApp"
            short="WhatsApp"
            copyText
            text={dailyShareText({
              day: istToday(),
              correct: me.correct,
              total_ms: me.total_ms,
              grid,
              streak: profile?.streak ?? 0,
              code: duel.code,
            })}
            onShare={logShare("daily")}
            beside={story}
          />
        ) : shareCode ? (
          <SharePanel
            code={shareCode}
            short="WhatsApp"
            text={challengeShareText(me.name, me.correct, me.total_ms, shareCode)}
            onShare={logShare("challenge")}
            beside={story}
          />
        ) : (
          <div className="flex gap-2.5">
            <button
              onClick={makeShareCode}
              disabled={busy !== null}
              className="flex h-14 min-w-0 flex-1 items-center justify-center gap-2.5 rounded-2xl bg-lime px-3 text-base font-bold whitespace-nowrap text-ink hover:bg-lime-hover disabled:opacity-70"
            >
              {/* Below 380 px wide there's only room for the words. */}
              <Bolt size={20} strokeWidth={2.4} className="shrink-0 max-[379px]:hidden" />
              {busy === "share" ? (
                "Making link…"
              ) : (
                <>
                  <span className="sm:hidden">Challenge friends</span>
                  <span className="max-sm:hidden">Challenge friends with your score</span>
                </>
              )}
            </button>
            {story}
          </div>
        )}
        {storyShared && (
          <p className="-mt-0.5 text-[13px] text-muted">Your link is copied too: add it to your Story with Instagram&apos;s Link sticker.</p>
        )}
        <div className="grid grid-cols-2 gap-2.5">
          <Link
            href={rematch ? `/play/${rematch.slug}` : "/play"}
            className="flex h-[52px] items-center justify-center gap-2 rounded-2xl border border-line bg-surface text-[15px] font-semibold text-text hover:bg-raised hover:text-text"
          >
            <Refresh size={18} strokeWidth={2.2} />
            {rematch ? `${rematch.name} again` : "Quick Match"}
          </Link>
          <button
            onClick={() => setShowReview((v) => !v)}
            aria-expanded={showReview}
            className="flex h-[52px] items-center justify-center gap-2 rounded-2xl border border-line bg-surface text-[15px] font-semibold hover:bg-raised"
          >
            {showReview ? "Hide answers" : "Review answers"}
          </button>
        </div>
        {error && <ErrorNote message={error} />}
      </section>

      {showReview && duel.review && <Review duelId={duel.id} items={duel.review} opponentName={opp?.finished ? opp.name : null} />}
    </div>
  );
}

const CONFETTI_COLORS = ["#c8f135", "#ff8a4c", "#a594ff", "#ff8f9b", "#f2f4f8", "#5ce1e6"];

// A one-off burst for wins. Positions are fixed per piece (not random) so
// server and browser render the same thing.
function Confetti() {
  return (
    <div aria-hidden="true" className="pointer-events-none fixed inset-x-0 top-0 z-30 h-0 motion-reduce:hidden">
      {Array.from({ length: 36 }, (_, i) => (
        <span
          key={i}
          className="absolute top-0 block rounded-[2px] motion-safe:animate-confetti"
          style={
            {
              left: `${(i * 37 + 7) % 100}%`,
              width: i % 3 === 0 ? 6 : 9,
              height: i % 3 === 0 ? 14 : 9,
              background: CONFETTI_COLORS[i % CONFETTI_COLORS.length],
              animationDelay: `${(i % 9) * 70}ms`,
              "--drift": `${((i * 53) % 160) - 80}px`,
              "--spin": `${360 + ((i * 97) % 540)}deg`,
            } as React.CSSProperties
          }
        />
      ))}
    </div>
  );
}

function Hero({ duel, outcome }: { duel: Duel; outcome: Outcome | null }) {
  const { me, opponent: opp } = duel;
  const summary = `${me.correct}/5 correct in ${clock(me.total_ms)} · ${me.score} points`;

  let title: string;
  let line: string;
  let titleTone = "text-text";
  let mood: TikoMood = "happy";

  if (outcome && opp) {
    const gap = Math.abs(me.score - opp.score);
    if (outcome === "win") {
      title = "You won!";
      line = gap ? `You beat ${opp.name} by ${gap} points` : `Same points as ${opp.name}, but you were faster`;
      titleTone = "text-lime";
      mood = "cheer";
    } else if (outcome === "loss") {
      title = "You lost";
      line = gap ? `${opp.name} won by ${gap} points. Run it back?` : `Same points, but ${opp.name} was faster`;
      titleTone = "text-orange";
      mood = "sad";
    } else {
      title = "It's a draw";
      line = "Same points, same time";
    }
  } else if (opp && duel.mode === "live") {
    title = `Waiting for ${opp.name}`;
    line = `${summary}. ${opp.name} is on question ${Math.min(opp.answered + 1, 5)} of 5 with ${opp.score} points.`;
    mood = "think";
  } else if (opp) {
    title = `Waiting for ${opp.name}`;
    line = `${summary}. This page updates when they finish.`;
    mood = "think";
  } else if (duel.mode === "daily") {
    title = duel.daily ? `#${duel.daily.rank} today` : "Daily done";
    line = duel.daily
      ? `${summary}. You're #${duel.daily.rank} of ${duel.daily.players} who played today's set.`
      : summary;
    titleTone = "text-violet-soft";
    mood = duel.daily && duel.daily.rank <= 3 ? "cheer" : "happy";
  } else if (duel.mode === "quick") {
    title = "Run saved";
    line = `${summary}. No one near your rating was free, so players who match with you will race this run.`;
  } else {
    title = "Score set";
    line = `${summary}. Your friends get the same 5 questions.`;
    mood = "wave";
  }

  return (
    <div className="flex flex-col items-center gap-2 text-center">
      <Tiko mood={mood} size={104} className="motion-safe:animate-pop" />
      <h1 className={`mt-1 font-display text-3xl font-bold ${titleTone}`}>{title}</h1>
      <p className="max-w-sm text-[15px] text-muted">{line}</p>
    </div>
  );
}

type Outcome = "win" | "loss" | "draw";

// Final scores side by side, with the winner called out.
function Scoreboard({ me, opp, outcome }: { me: Player; opp: Player; outcome: Outcome }) {
  const flip: Record<Outcome, Outcome> = { win: "loss", loss: "win", draw: "draw" };
  return (
    <Card className="sticker grid grid-cols-[1fr_auto_1fr] items-stretch gap-2 px-3 pt-4 pb-3 sm:gap-3 sm:px-4">
      <ScoreSide player={me} label="You" outcome={outcome} />
      <span className="-rotate-6 self-center rounded-md bg-raised px-2 py-1 font-display text-[12px] font-bold text-soft">VS</span>
      <ScoreSide player={opp} outcome={flip[outcome]} />
    </Card>
  );
}

// A rubber stamp, slammed on at an angle.
function Stamp({ text, tone, tilt }: { text: string; tone: string; tilt: string }) {
  return (
    <span
      className={`pointer-events-none absolute top-1.5 right-1.5 rounded-md border-[3px] border-double px-1.5 py-0.5 font-display text-[10px] font-bold tracking-widest opacity-90 motion-safe:animate-stamp sm:top-3 sm:right-2 sm:px-2 sm:text-[13px] ${tone}`}
      style={{ transform: `rotate(${tilt})`, ["--tilt" as string]: tilt }}
    >
      {text}
    </span>
  );
}

function ScoreSide({ player, label, outcome }: { player: Player; label?: string; outcome: Outcome }) {
  const won = outcome === "win";
  return (
    <div
      className={`relative flex min-w-0 flex-col items-center gap-1 rounded-2xl border-2 px-2 pt-10 pb-4 text-center ${
        won ? "border-lime bg-lime-tint" : "border-transparent bg-raised/60"
      }`}
    >
      {won && <Stamp text="CLEARED" tone="border-lime text-lime" tilt="12deg" />}
      {outcome === "loss" && <Stamp text="RETRY" tone="border-red-soft text-red-soft" tilt="-10deg" />}
      {outcome === "draw" && <Stamp text="TIE" tone="border-soft text-soft" tilt="8deg" />}
      <PlayerAvatar name={player.name} bot={player.is_bot} size={52} />
      <span className="mt-1 max-w-full truncate text-sm font-semibold">
        {!label && player.id && !player.is_bot ? (
          <Link href={`/u/${player.id}`} className="text-text underline decoration-line-strong underline-offset-4 hover:text-lime">
            {player.name}
          </Link>
        ) : (
          (label ?? player.name)
        )}
        {player.is_bot && <BotTag />}
      </span>
      <span className={`font-mono text-[40px] leading-none font-bold ${won ? "text-lime" : "text-text"}`}>
        {player.score}
      </span>
      <span className="text-xs text-muted">points</span>
      <span className="mt-1 font-mono text-xs text-soft">
        {player.correct}/5 · {clock(player.total_ms)}
      </span>
      {won && (
        <span className="mt-1.5 flex items-center gap-1 rounded-full bg-lime px-2.5 py-0.5 text-[11px] font-bold tracking-wider text-ink">
          <Trophy size={12} strokeWidth={2.6} />
          WINNER
        </span>
      )}
    </div>
  );
}

function RatingCard({ before, after, delta }: { before: number; after: number; delta: number }) {
  const was = tierFor(before);
  const now = tierFor(after);
  const promoted = now.min > was.min;
  return (
    <Card className="flex flex-col gap-3 p-4">
      <div className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          <span className="text-[13px] text-muted">Rating</span>
          <span className="flex items-center gap-2.5 font-display font-bold">
            <span className="font-mono text-lg text-muted">{before.toLocaleString("en-IN")}</span>
            <span aria-hidden="true" className="text-muted">→</span>
            <span className="font-mono text-2xl">{after.toLocaleString("en-IN")}</span>
          </span>
        </div>
        <span
          className={`rounded-full px-3 py-1.5 text-[15px] font-bold ${
            delta >= 0 ? "bg-lime text-ink" : "bg-red-tint text-red-soft"
          }`}
        >
          {signed(delta)}
        </span>
      </div>
      {promoted && (
        <div className="flex items-center gap-3 rounded-[14px] bg-violet-tint p-3">
          <span className="flex size-9 items-center justify-center rounded-xl bg-violet-strong text-violet-soft">
            <Shield size={18} strokeWidth={2.2} />
          </span>
          <span className="flex flex-col">
            <span className="text-sm font-bold text-violet-soft">Promoted to {now.name}</span>
            {now.next && <span className="text-xs text-violet">Next: {now.next.name} at {now.next.min.toLocaleString("en-IN")}</span>}
          </span>
        </div>
      )}
    </Card>
  );
}

function AnswerDots({ review }: { review: ReviewItem[] }) {
  return (
    <div className="flex items-center justify-between px-1">
      <span className="text-[13px] text-muted">Your answers</span>
      <div className="flex gap-2">
        {review.map((r) =>
          r.is_correct ? (
            <span key={r.q_index} className="flex size-[26px] items-center justify-center rounded-full bg-lime text-ink">
              <Check size={13} strokeWidth={3.2} />
              <span className="sr-only">Question {r.q_index + 1} correct</span>
            </span>
          ) : (
            <span key={r.q_index} className="flex size-[26px] items-center justify-center rounded-full bg-red-tint text-red">
              <Close size={12} strokeWidth={3.2} />
              <span className="sr-only">Question {r.q_index + 1} wrong</span>
            </span>
          ),
        )}
      </div>
    </div>
  );
}

function Review({ duelId, items, opponentName }: { duelId: string; items: ReviewItem[]; opponentName: string | null }) {
  return (
    <section className="flex flex-col gap-3" aria-label="Answer review">
      {items.map((r) => (
        <Card key={r.q_index} className="flex flex-col gap-3 p-4">
          <div className="flex flex-wrap items-center justify-between gap-2 text-xs">
            <span className="font-semibold text-muted">
              Q{r.q_index + 1} · {r.topic}
              {r.companies?.length > 0 && <span className="text-violet"> · {r.companies.join(", ")} pattern</span>}
            </span>
            <span className={r.is_correct ? "font-bold text-lime" : "font-bold text-red-soft"}>
              {r.is_correct ? `+${r.points} · ${clock(r.ms)}` : r.chosen_idx === null ? "Time ran out" : "Wrong"}
            </span>
          </div>
          <p className="text-[15px] leading-relaxed font-semibold">{r.body}</p>
          {r.figure && (
            <Figure
              svg={r.figure}
              label="Question figure"
              className="w-full max-w-[420px] rounded-xl border border-line p-2 text-text [&>svg]:max-h-[200px]"
            />
          )}
          <ul className={r.option_figures ? "grid grid-cols-4 gap-2" : "flex flex-col gap-1.5"}>
            {r.options.map((o, i) => {
              const right = i === r.correct_idx;
              const mine = i === r.chosen_idx;
              const tone = right ? "border-lime bg-lime-tint" : mine ? "border-red bg-red-tint" : "border-line";
              const note = right ? "Correct answer" : mine ? "Your answer" : "";
              const figure = r.option_figures?.[i];
              if (figure) {
                return (
                  <li key={i} className={`flex flex-col items-center gap-1 rounded-xl border p-1.5 ${tone}`}>
                    <span className="text-[11px] font-bold text-muted">{"ABCD"[i]}</span>
                    <Figure svg={figure} label={`Option ${"ABCD"[i]}${note ? `, ${note.toLowerCase()}` : ""}`} className="aspect-square w-full text-text" />
                  </li>
                );
              }
              return (
                <li key={i} className={`flex items-center justify-between gap-2 rounded-xl border px-3 py-2 text-sm ${tone}`}>
                  <span>{o}</span>
                  <span className="text-xs font-semibold text-muted">{note}</span>
                </li>
              );
            })}
          </ul>
          <p className="text-sm leading-relaxed text-soft">{r.explanation}</p>
          <div className="flex items-center justify-between gap-3">
            {opponentName && r.opp_correct !== null ? (
              <p className="text-xs text-muted">
                {opponentName}: {r.opp_correct ? "got it right" : "got it wrong"}
              </p>
            ) : (
              <span />
            )}
            <button
              onClick={() =>
                openFeedback("question", {
                  duel: duelId,
                  question: r.q_index + 1,
                  topic: r.topic,
                  body: r.body.slice(0, 240),
                })
              }
              className="shrink-0 text-xs font-semibold text-muted underline-offset-2 hover:text-text hover:underline"
            >
              Report this question
            </button>
          </div>
        </Card>
      ))}
    </section>
  );
}

// Today in India, as YYYY-MM-DD: the Daily's day.
function istToday() {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Kolkata" }).format(new Date());
}

const MODE_CHIP: Record<string, string> = { quick: "QUICK MATCH", live: "LIVE DUEL", challenge: "CHALLENGE" };

// What the story card says. First person, so it needs no name; a win over
// a bot doesn't name the bot.
function storyData(duel: Duel, outcome: Outcome | null, grid: boolean[]): StoryData {
  const { me, opponent: opp } = duel;
  const chip =
    duel.mode === "daily"
      ? `DAILY · ${shortDay(istToday()).toUpperCase()}`
      : duel.company
        ? `${duel.company.toUpperCase()} PRACTICE`
        : (MODE_CHIP[duel.mode] ?? "APTITUDE DUEL");
  let headline = "My score";
  let extra: string | null = null;
  if (duel.mode === "daily") {
    headline = "Today's Daily";
    extra = duel.daily ? `#${duel.daily.rank} of ${duel.daily.players} today` : null;
  } else if (outcome === "win" && opp) {
    headline = "I won!";
    const gap = me.score - opp.score;
    extra = opp.is_bot ? null : gap > 0 ? `Beat ${opp.name} by ${gap} points` : `Beat ${opp.name} on time`;
  } else if (outcome === "draw") {
    headline = "It's a draw";
  }
  return { chip, headline, correct: me.correct, score: me.score, time: clock(me.total_ms), grid, extra };
}

// A guest is "Player 4821" until they pick a name. Asked here, where they're
// about to share, instead of sending them off to Profile.
function NameForm({ current, profile, onSaved }: { current: string; profile: Me | null; onSaved: (name: string) => void }) {
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save(e: FormEvent) {
    e.preventDefault();
    if (!profile) return;
    setBusy(true);
    setError(null);
    try {
      // Keeps the college and year already saved.
      const me = await api.updateProfile(name.trim(), profile.college_id, profile.grad_year);
      onSaved(me.name);
    } catch (err) {
      setError((err as Error).message);
      setBusy(false);
    }
  }

  return (
    <form onSubmit={save} className="flex flex-col gap-2.5 rounded-2xl border border-line bg-surface p-4">
      <label htmlFor="share-name" className="text-sm">
        <span className="font-semibold">What should friends call you?</span>
        <span className="block text-muted">They&apos;ll see “{current}” otherwise.</span>
      </label>
      <div className="flex gap-2">
        <input
          id="share-name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Your first name"
          maxLength={24}
          autoComplete="given-name"
          className="h-11 min-w-0 flex-1 rounded-xl border border-line bg-ink px-3 text-[15px] text-text"
        />
        <button
          type="submit"
          disabled={busy || !profile || name.trim().length < 2}
          className="h-11 shrink-0 rounded-xl bg-lime px-4 text-sm font-bold text-ink hover:bg-lime-hover disabled:opacity-60"
        >
          {busy ? "Saving…" : "Save"}
        </button>
      </div>
      {error && <p className="text-sm text-red-soft">{error}</p>}
    </form>
  );
}
