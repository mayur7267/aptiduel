"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { use, useEffect, useEffectEvent, useRef, useState } from "react";
import { api, type AnswerResult, type Duel, type QuestionView } from "@/lib/api";
import { clock } from "@/lib/format";
import { Check, Clock, Close } from "@/components/icons";
import { Figure } from "@/components/figure";
import { BotTag, ErrorNote, Spinner } from "@/components/ui";

type Question = Extract<QuestionView, { done: false }>;
type Mark = "right" | "wrong" | "unknown";
type Phase = "loading" | "question" | "submitting" | "reveal";

const KEYS = ["A", "B", "C", "D"];
const SECTION_LABEL: Record<string, string> = { quant: "Quant", reasoning: "Reasoning", verbal: "Verbal" };

export function DuelPlay({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();

  const [duel, setDuel] = useState<Duel | null>(null);
  const [q, setQ] = useState<Question | null>(null);
  const [phase, setPhase] = useState<Phase>("loading");
  const [chosen, setChosen] = useState<number | null>(null);
  const [result, setResult] = useState<AnswerResult | null>(null);
  const [score, setScore] = useState(0);
  const [marks, setMarks] = useState<Mark[]>([]);
  const [remaining, setRemaining] = useState(0);
  const [error, setError] = useState<string | null>(null);
  // Question whose opponent result has been shown (see submit).
  const [oppRevealed, setOppRevealed] = useState(-1);
  const deadline = useRef(0);
  const answered = useRef(-1);
  // Next keeps this page mounted (hidden) after you leave. Pending timers
  // must not load the next question then, or its clock would start while
  // you're away.
  const visible = useRef(true);
  const timers = useRef<number[]>([]);

  function later(fn: () => void, ms: number) {
    timers.current.push(window.setTimeout(() => visible.current && fn(), ms));
  }

  function show(next: QuestionView) {
    if (next.done) {
      router.replace(`/duel/${id}/result`);
      return;
    }
    deadline.current = performance.now() + next.remaining_ms;
    setQ(next);
    setScore(next.score);
    setChosen(null);
    setResult(null);
    setRemaining(next.remaining_ms);
    setMarks((m) => (m.length < next.q_index ? [...m, ...Array<Mark>(next.q_index - m.length).fill("unknown")] : m));
    setPhase("question");
  }

  async function loadNext() {
    if (!visible.current) return;
    try {
      show(await api.nextQuestion(id));
    } catch (e) {
      setError((e as Error).message);
    }
  }

  const onLoaded = useEffectEvent((d: Duel, next: QuestionView) => {
    setDuel(d);
    // Restore right/wrong dots for questions answered before a refresh.
    setMarks((d.my_answers ?? []).map((a) => (a.correct ? "right" : "wrong")));
    show(next);
  });

  useEffect(() => {
    let active = true;
    visible.current = true;
    Promise.all([api.getDuel(id), api.nextQuestion(id)])
      .then(([d, next]) => active && onLoaded(d, next))
      .catch((e: Error) => active && setError(e.message));
    return () => {
      active = false;
      visible.current = false;
      timers.current.forEach(clearTimeout);
      timers.current = [];
    };
  }, [id]);

  async function submit(choice: number | null) {
    if (!q || phase !== "question" || answered.current === q.q_index) return;
    answered.current = q.q_index;
    const myMs = q.time_limit_ms - Math.max(0, deadline.current - performance.now());
    setChosen(choice);
    setPhase("submitting");
    try {
      const r = await api.submitAnswer(id, q.q_index, choice);
      if (!visible.current) return;
      setResult(r);
      setScore(r.score);
      setMarks((m) => [...m, r.correct ? "right" : "wrong"]);
      setPhase("reveal");
      // If you beat the opponent to it, they answer a moment later rather
      // than at the same instant, which would look rigged.
      const step = duel?.opponent_timeline?.find((s) => s.q_index === q.q_index);
      const wait = step && step.ms > myMs ? Math.min(step.ms - myMs, 1200 + Math.random() * 2000) : 0;
      const index = q.q_index;
      later(() => setOppRevealed(index), wait);
      later(() => {
        if (r.done) router.replace(`/duel/${id}/result`);
        else loadNext();
      }, wait + (r.correct ? 900 : 1500));
    } catch (e) {
      // Usually a double submit after a refresh: just move on.
      if ((e as Error).message.includes("already answered")) loadNext();
      else setError((e as Error).message);
    }
  }

  const tick = useEffectEvent(() => {
    const left = Math.max(0, deadline.current - performance.now());
    setRemaining(left);
    if (left === 0) submit(null);
  });

  useEffect(() => {
    if (phase !== "question") return;
    const timer = setInterval(tick, 100);
    return () => clearInterval(timer);
  }, [phase]);

  const onKey = useEffectEvent((e: KeyboardEvent) => {
    const i = ["1", "2", "3", "4"].indexOf(e.key);
    const j = KEYS.indexOf(e.key.toUpperCase());
    const pick = i >= 0 ? i : j;
    if (pick >= 0 && !e.metaKey && !e.ctrlKey) submit(pick);
  });

  useEffect(() => {
    const handler = (e: KeyboardEvent) => onKey(e);
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, []);

  if (error) {
    return (
      <div className="flex flex-col gap-4 pt-10">
        <ErrorNote message={error} onRetry={() => location.reload()} />
        <Link href="/" className="text-sm font-semibold">Back to home</Link>
      </div>
    );
  }
  if (!q) return <Spinner label="Loading duel" />;

  const opp = duel?.opponent ?? null;
  const fraction = q.time_limit_ms ? remaining / q.time_limit_ms : 0;
  const urgent = remaining < 10_000 && phase === "question";

  // Replay a finished opponent's run on the same question you're on. They
  // "answer" once your time on the question passes theirs, but whether
  // they were right stays hidden until you answer too.
  const elapsedHere = q.time_limit_ms - remaining;
  const revealedHere = phase === "reveal" && oppRevealed === q.q_index;
  const oppMarks: Mark[] = [];
  let oppScore = 0;
  let oppAnsweredHere = false;
  for (const step of duel?.opponent_timeline ?? []) {
    if (step.q_index < q.q_index || (step.q_index === q.q_index && revealedHere)) {
      oppScore += step.points;
      oppMarks.push(step.correct ? "right" : "wrong");
    } else if (step.q_index === q.q_index && step.ms <= elapsedHere) {
      oppAnsweredHere = true;
      oppMarks.push("unknown");
    }
  }
  const oppStatus = revealedHere ? "" : oppAnsweredHere ? "Answered" : "Thinking";
  const waitingFor =
    phase === "reveal" && !revealedHere && opp && duel?.opponent_timeline ? opp.name : null;

  return (
    <div className="flex flex-1 flex-col gap-4">
      <div className="flex items-center justify-between">
        <Link
          href="/"
          aria-label="Leave duel"
          className="flex size-11 items-center justify-center rounded-full border border-line bg-surface hover:bg-raised"
        >
          <Close size={18} strokeWidth={2.2} />
        </Link>
        <span className="text-[15px] font-semibold">
          Question {q.q_index + 1} of {q.total}
        </span>
        <span
          className={`flex h-9 items-center gap-1.5 rounded-full border px-3 font-mono text-[15px] font-bold ${
            urgent ? "border-orange/40 bg-orange-tint text-orange" : "border-line bg-surface"
          }`}
        >
          <Clock size={16} strokeWidth={2.2} className={urgent ? "" : "text-lime"} />
          <span aria-live="off">{clock(remaining)}</span>
        </span>
      </div>

      <div className="sticker grid grid-cols-[1fr_auto_1fr] items-center gap-2 rounded-[20px] border-2 border-line bg-[linear-gradient(90deg,rgba(200,241,53,0.09),transparent_42%,transparent_58%,rgba(255,138,76,0.09))] bg-surface p-4">
        <div className="flex flex-col gap-2">
          <span className="text-sm font-semibold">You</span>
          <span key={score} className="font-mono text-[28px] leading-none font-bold text-lime motion-safe:animate-pop">
            {score}
          </span>
          <ProgressDots marks={marks} current={q.q_index} total={q.total} />
        </div>
        <span className="-rotate-6 rounded-md bg-raised px-2 py-1 font-display text-[12px] font-bold text-soft">VS</span>
        <div className="flex min-w-0 flex-col items-end gap-2 text-right">
          {opp?.finished && duel?.opponent_timeline ? (
            <>
              <span className="flex max-w-full items-center gap-1.5 text-sm font-semibold">
                <span className="truncate">{opp.name}</span>
                {opp.is_bot && <BotTag />}
              </span>
              <span
                key={oppScore}
                className="font-mono text-[28px] leading-none font-bold text-orange motion-safe:animate-pop"
              >
                {oppScore}
              </span>
              <ProgressDots
                marks={oppMarks}
                current={oppAnsweredHere ? -1 : q.q_index}
                total={q.total}
                ring="border-orange"
              />
              <span className="flex h-4 items-center gap-1 text-xs font-semibold text-muted" aria-live="polite">
                {oppStatus === "Thinking" && (
                  <span aria-hidden="true" className="flex gap-0.5">
                    {[0, 150, 300].map((d) => (
                      <span
                        key={d}
                        className="size-1 rounded-full bg-orange motion-safe:animate-dot"
                        style={{ animationDelay: `${d}ms` }}
                      />
                    ))}
                  </span>
                )}
                {oppStatus === "Answered" && <Check size={12} strokeWidth={3} className="text-orange" />}
                {oppStatus}
              </span>
            </>
          ) : opp?.finished ? (
            <>
              <span className="text-sm font-semibold">{opp.name}</span>
              <span className="font-display text-2xl font-bold text-orange tabular-nums">{opp.score}</span>
              <span className="text-xs text-muted">score to beat</span>
            </>
          ) : opp ? (
            <>
              <span className="text-sm font-semibold">{opp.name}</span>
              <span className="text-xs text-muted">playing now</span>
            </>
          ) : duel?.mode === "daily" ? (
            <>
              <span className="text-sm font-semibold">Daily challenge</span>
              <span className="text-xs text-muted">Same 5 questions for everyone today</span>
            </>
          ) : duel?.mode === "quick" ? (
            <>
              <span className="text-sm font-semibold">Solo run</span>
              <span className="text-xs text-muted">No one near your rating yet. Others will race this run.</span>
            </>
          ) : (
            <>
              <span className="text-sm font-semibold">Your friend</span>
              <span className="text-xs text-muted">You set the score. Send the link after.</span>
            </>
          )}
        </div>
      </div>

      <div
        role="progressbar"
        aria-label="Time left"
        aria-valuemin={0}
        aria-valuemax={Math.round(q.time_limit_ms / 1000)}
        aria-valuenow={Math.round(remaining / 1000)}
        className="h-2.5 overflow-hidden rounded-full bg-line"
      >
        {/* A fuse with tick marks, burning down. */}
        <div
          className={`h-full rounded-full bg-[repeating-linear-gradient(90deg,transparent_0_12px,rgb(11_14_23/0.4)_12px_14px)] transition-[width] duration-100 ${
            urgent ? "bg-orange" : "bg-lime"
          }`}
          style={{ width: `${Math.round(fraction * 1000) / 10}%` }}
        />
      </div>

      <div className="flex flex-wrap gap-2">
        <span className="rounded-lg bg-raised px-2.5 py-1 text-xs font-semibold text-soft">{q.topic}</span>
        <span className="rounded-lg bg-raised px-2.5 py-1 text-xs font-semibold text-soft">{SECTION_LABEL[q.section] ?? q.section}</span>
        {q.companies?.length > 0 && (
          <span
            title="This topic is part of these companies' aptitude tests"
            className="rounded-lg bg-violet-tint px-2.5 py-1 text-xs font-semibold text-violet"
          >
            {q.companies.join(" · ")} pattern
          </span>
        )}
      </div>

      <p className="text-lg leading-relaxed font-semibold">{q.body}</p>

      {q.figure && (
        <Figure
          svg={q.figure}
          label="Question figure"
          className="mx-auto w-full max-w-[540px] rounded-2xl border border-line bg-surface p-3 text-text [&>svg]:max-h-[210px]"
        />
      )}

      {/* Pinned to the bottom on phones for thumbs; right under the question on bigger screens. */}
      <div className="mt-auto flex flex-col gap-2.5 pt-2 sm:mt-4">
        <div className={q.option_figures ? "grid grid-cols-2 gap-2.5 sm:grid-cols-4" : "flex flex-col gap-2.5"}>
          {q.options.map((text, i) => (
            <OptionButton
              key={i}
              index={i}
              text={text}
              figure={q.option_figures?.[i]}
              phase={phase}
              chosen={chosen}
              result={result}
              onPick={() => submit(i)}
            />
          ))}
        </div>
        <Feedback phase={phase} result={result} chosen={chosen} waitingFor={waitingFor} />
        <p className="hidden text-center text-xs text-faint sm:block">Tip: press 1–4 or A–D to answer</p>
      </div>
    </div>
  );
}

function OptionButton({
  index,
  text,
  figure,
  phase,
  chosen,
  result,
  onPick,
}: {
  index: number;
  text: string;
  figure?: string; // picture option
  phase: Phase;
  chosen: number | null;
  result: AnswerResult | null;
  onPick: () => void;
}) {
  const revealed = phase === "reveal" && result;
  const isCorrect = revealed && result.correct_idx === index;
  const isWrongPick = revealed && chosen === index && !result.correct;
  const isPending = phase === "submitting" && chosen === index;

  // Like an OMR sheet: a lettered bubble that gets filled in.
  let look = "border-line bg-surface hover:border-line-strong hover:bg-raised [--pop:#232a3b]";
  let bubble = "border-line-strong text-muted group-hover:border-text group-hover:text-text";
  if (isCorrect) {
    look = "border-lime bg-lime-tint [--pop:#4b5d0c]";
    bubble = "border-lime bg-lime text-ink";
  } else if (isWrongPick) {
    look = "border-red bg-red-tint [--pop:#5a2230]";
    bubble = "border-red bg-red text-ink";
  } else if (isPending) {
    look = "border-text bg-raised [--pop:#232a3b]";
    bubble = "border-text bg-text text-ink";
  } else if (revealed) {
    look = "border-line bg-surface opacity-45 [--pop:transparent]";
  }

  const mark = (
    <span
      className={`flex size-[30px] shrink-0 items-center justify-center rounded-full border-2 font-mono text-[13px] font-bold transition-colors ${bubble}`}
    >
      {isCorrect ? <Check size={15} strokeWidth={3} /> : KEYS[index]}
    </span>
  );

  if (figure) {
    return (
      <button
        onClick={onPick}
        disabled={phase !== "question"}
        aria-label={`Option ${KEYS[index]}`}
        className={`group pressable relative flex aspect-square items-center justify-center rounded-2xl border-2 disabled:cursor-default ${look}`}
      >
        <span className="absolute top-2 left-2">{mark}</span>
        <Figure svg={figure} className="size-[72%] text-text" />
      </button>
    );
  }

  return (
    <button
      onClick={onPick}
      disabled={phase !== "question"}
      className={`group pressable flex min-h-[60px] items-center gap-3.5 rounded-2xl border-2 px-4 text-left text-base font-semibold disabled:cursor-default ${look}`}
    >
      {mark}
      <span>{text}</span>
    </button>
  );
}

function Feedback({
  phase,
  result,
  chosen,
  waitingFor,
}: {
  phase: Phase;
  result: AnswerResult | null;
  chosen: number | null;
  waitingFor: string | null;
}) {
  let text = "";
  let tone = "text-muted";
  if (phase === "reveal" && result) {
    if (result.correct) {
      text = `+${result.points} points`;
      tone = "text-lime";
    } else {
      text = chosen === null ? "Time's up" : "Not quite";
      tone = "text-red-soft";
    }
  }
  return (
    <p aria-live="polite" className={`flex h-6 items-center justify-center gap-2 text-sm font-bold ${tone}`}>
      {text}
      {waitingFor && <span className="font-medium text-muted">· Waiting for {waitingFor}…</span>}
    </p>
  );
}

function ProgressDots({
  marks,
  current,
  total,
  ring = "border-text",
}: {
  marks: Mark[];
  current: number;
  total: number;
  ring?: string;
}) {
  return (
    <div className="flex gap-1.5" aria-label={`${marks.filter((m) => m === "right").length} correct so far`}>
      {Array.from({ length: total }, (_, i) => {
        const m = marks[i];
        if (m === "right")
          return (
            <span key={i} className="flex size-5 items-center justify-center rounded-full bg-lime text-ink">
              <Check size={11} strokeWidth={3.5} />
            </span>
          );
        if (m === "wrong")
          return (
            <span key={i} className="flex size-5 items-center justify-center rounded-full bg-red-tint text-red">
              <Close size={10} strokeWidth={3.5} />
            </span>
          );
        if (m === "unknown") return <span key={i} className="size-5 rounded-full bg-line-strong" />;
        if (i === current) return <span key={i} className={`size-5 rounded-full border-2 ${ring}`} />;
        return <span key={i} className="size-5 rounded-full bg-line" />;
      })}
    </div>
  );
}
