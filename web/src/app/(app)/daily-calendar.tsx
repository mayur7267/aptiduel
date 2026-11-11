"use client";

import { useEffect, useMemo, useState, type ReactNode } from "react";
import { api, type Me } from "@/lib/api";
import { istKey, monthGrid, monthOf, monthTitle, runs, sameOrBefore, shiftMonth, weekDays, type Cell } from "@/lib/daily-calendar";
import { Check, ChevronLeft, ChevronRight, Flame, Trophy } from "@/components/icons";
import { Modal } from "@/components/modal";
import { ErrorNote } from "@/components/ui";

const WEEKDAYS = ["M", "T", "W", "T", "F", "S", "S"];

// Every day you finished the Daily Challenge, a month at a time, opened
// from the Daily card's "View all". Days in a row join into one band, so a
// run reads at a glance.
export function DailyCalendar({
  open,
  onClose,
  ...body
}: {
  open: boolean;
  onClose: () => void;
  me: Me;
  nowMs: number;
  busy: boolean;
  onPlay: () => void;
}) {
  return (
    <Modal open={open} onClose={onClose} title="Daily calendar">
      <CalendarBody {...body} />
    </Modal>
  );
}

// Mounted while the calendar is open, so each opening starts on this
// month and fetches the days afresh.
function CalendarBody({ me, nowMs, busy, onPlay }: { me: Me; nowMs: number; busy: boolean; onPlay: () => void }) {
  const today = istKey(nowMs);
  const [fetched, setFetched] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  const [month, setMonth] = useState(() => monthOf(today));

  useEffect(() => {
    let active = true;
    api.dailyDays().then(
      (days) => {
        if (!active) return;
        setFetched(days);
        setError(null);
      },
      (e: Error) => active && setError(e.message),
    );
    return () => {
      active = false;
    };
  }, [attempt]);

  // This week comes from home, which already has it, so the calendar
  // never opens empty.
  const done = useMemo(
    () => new Set([...weekDays(me.daily_week, me.today_idx, nowMs), ...fetched]),
    [me.daily_week, me.today_idx, nowMs, fetched],
  );
  const run = runs(done, today);
  const thisMonth = monthOf(today);
  // Back as far as your first Daily.
  const first = done.size ? monthOf([...done].sort()[0]) : thisMonth;
  const canBack = !sameOrBefore(month, sameOrBefore(first, thisMonth) ? first : thisMonth);
  const canForward = !sameOrBefore(thisMonth, month);
  const weeks = monthGrid(month, done, today);
  const inMonth = weeks.flat().filter((c) => c.done).length;

  return (
    <div className="flex flex-col gap-4">
      <p className="-mt-3 text-sm text-muted">Every day you finished the Daily Challenge.</p>
      <div className="grid grid-cols-3 gap-2.5">
        <Stat value={run.current} label="in a row" icon={<Flame size={15} />} color="text-orange" />
        <Stat value={run.best} label="best run" icon={<Trophy size={15} />} color="text-violet" />
        <Stat value={run.total} label="all time" icon={<Check size={15} strokeWidth={3} />} color="text-lime" />
      </div>
      <div className="flex flex-col gap-2.5 rounded-[18px] border border-line bg-raised p-3.5">
        <div className="flex items-center justify-between gap-2">
          <Arrow label="Previous month" enabled={canBack} onClick={() => setMonth(shiftMonth(month, -1))}>
            <ChevronLeft size={16} strokeWidth={2.6} />
          </Arrow>
          <div className="text-center" aria-live="polite">
            <div className="text-base font-bold">{monthTitle(month)}</div>
            <div className="text-xs text-muted">{inMonth === 1 ? "1 day done" : `${inMonth} days done`}</div>
          </div>
          <Arrow label="Next month" enabled={canForward} onClick={() => setMonth(shiftMonth(month, 1))}>
            <ChevronRight size={16} strokeWidth={2.6} />
          </Arrow>
        </div>
        <div aria-hidden="true" className="grid grid-cols-7 text-center font-mono text-[11px] text-faint">
          {WEEKDAYS.map((d, i) => (
            <span key={i}>{d}</span>
          ))}
        </div>
        <div className="flex flex-col gap-1.5">
          {weeks.map((week) => (
            <div key={week[0].key} className="grid grid-cols-7">
              {week.map((cell, i) => (
                <Day
                  key={cell.key}
                  cell={cell}
                  joinsLeft={cell.done && i > 0 && week[i - 1].done}
                  joinsRight={cell.done && i < 6 && week[i + 1].done}
                />
              ))}
            </div>
          ))}
        </div>
      </div>
      {error && <ErrorNote message={error} onRetry={() => setAttempt((a) => a + 1)} />}
      {me.quests.daily === 0 && (
        <button
          onClick={onPlay}
          disabled={busy}
          className="pressable h-12 rounded-[14px] bg-text text-[15px] font-bold text-ink [--pop:#3a3270] disabled:opacity-70"
        >
          {busy ? "Opening…" : "Play today's set"}
        </button>
      )}
    </div>
  );
}

function Day({ cell, joinsLeft, joinsRight }: { cell: Cell; joinsLeft: boolean; joinsRight: boolean }) {
  if (cell.day === null) return <span aria-hidden="true" className="h-9" />;
  return (
    <span className="relative flex h-9 items-center justify-center">
      {joinsLeft && <span aria-hidden="true" className="absolute inset-y-1 left-0 w-1/2 bg-lime/30" />}
      {joinsRight && <span aria-hidden="true" className="absolute inset-y-1 right-0 w-1/2 bg-lime/30" />}
      <span
        className={`relative flex size-9 items-center justify-center rounded-full font-mono text-[13px] ${
          cell.done
            ? "bg-lime font-extrabold text-ink"
            : cell.today
              ? "border-2 border-dashed border-lime font-medium text-lime"
              : cell.future
                ? "font-medium text-faint/45"
                : "font-medium text-muted"
        }`}
      >
        {cell.day}
      </span>
      <span className="sr-only">{cell.done ? ", done" : cell.today ? ", today" : ""}</span>
    </span>
  );
}

function Stat({ value, label, icon, color }: { value: number; label: string; icon: ReactNode; color: string }) {
  return (
    <div className="flex flex-col gap-1 rounded-2xl border border-line bg-raised p-3">
      <span aria-hidden="true" className={color}>
        {icon}
      </span>
      <span className="font-mono text-[22px] leading-none font-bold">{value}</span>
      <span className="text-xs text-muted">{label}</span>
    </div>
  );
}

function Arrow({ label, enabled, onClick, children }: { label: string; enabled: boolean; onClick: () => void; children: ReactNode }) {
  return (
    <button
      onClick={onClick}
      disabled={!enabled}
      aria-label={label}
      className="flex size-9 items-center justify-center rounded-full bg-surface text-text hover:bg-line disabled:text-faint/40 disabled:hover:bg-surface"
    >
      {children}
    </button>
  );
}
