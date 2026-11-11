// The calendar behind the Daily card: every day you finished the Daily
// Challenge (daily_days, supabase/migrations/0016_daily_calendar.sql), a
// month at a time. Days are IST "YYYY-MM-DD" keys, like the server's, and
// weeks start on Monday, like the week on the card.

const IST = 5.5 * 3_600_000;
const DAY = 86_400_000;

// The IST day of an instant.
export function istKey(ms: number) {
  return new Date(ms + IST).toISOString().slice(0, 10);
}

// A day key moved by n days.
export function addDays(key: string, n: number) {
  return new Date(Date.parse(key) + n * DAY).toISOString().slice(0, 10);
}

// This week from home (get_me's daily_week), which is already loaded, so
// the calendar never opens empty while the rest comes from the server.
export function weekDays(week: boolean[], todayIdx: number, nowMs: number) {
  const today = istKey(nowMs);
  return week.flatMap((done, i) => (done ? [addDays(today, i - todayIdx)] : []));
}

export type Month = { year: number; month: number }; // month 0-11

export function monthOf(key: string): Month {
  return { year: Number(key.slice(0, 4)), month: Number(key.slice(5, 7)) - 1 };
}

export function shiftMonth({ year, month }: Month, n: number): Month {
  const m = year * 12 + month + n;
  return { year: Math.floor(m / 12), month: ((m % 12) + 12) % 12 };
}

export const sameOrBefore = (a: Month, b: Month) => a.year * 12 + a.month <= b.year * 12 + b.month;

export function monthTitle({ year, month }: Month) {
  return new Date(Date.UTC(year, month, 1)).toLocaleDateString("en-IN", { month: "long", year: "numeric", timeZone: "UTC" });
}

export type Cell = { key: string; day: number | null; done: boolean; today: boolean; future: boolean };

// The month in six weeks of seven, blanks before the 1st and after the
// last, so the calendar keeps its height from month to month.
export function monthGrid({ year, month }: Month, done: Set<string>, today: string): Cell[][] {
  const count = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  const lead = (new Date(Date.UTC(year, month, 1)).getUTCDay() + 6) % 7;
  const cells: Cell[] = Array.from({ length: lead }, (_, i) => ({ key: `blank-${i}`, day: null, done: false, today: false, future: false }));
  for (let d = 1; d <= count; d++) {
    const key = new Date(Date.UTC(year, month, d)).toISOString().slice(0, 10);
    cells.push({ key, day: d, done: done.has(key), today: key === today, future: key > today });
  }
  while (cells.length < 42) cells.push({ key: `blank-${cells.length}`, day: null, done: false, today: false, future: false });
  return Array.from({ length: 6 }, (_, w) => cells.slice(w * 7, w * 7 + 7));
}

// Days in a row up to today, or up to yesterday while today's is open;
// the most in a row ever; and every day done.
export function runs(done: Set<string>, today: string) {
  let current = 0;
  for (let d = done.has(today) ? today : addDays(today, -1); done.has(d); d = addDays(d, -1)) current++;
  let best = 0;
  let run = 0;
  let last: string | null = null;
  for (const d of [...done].sort()) {
    run = last && addDays(last, 1) === d ? run + 1 : 1;
    best = Math.max(best, run);
    last = d;
  }
  return { current, best, total: done.size };
}
