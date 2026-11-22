// The Streak Tower: every day you play adds a block, every 7 blocks make a
// floor in a new colour, and milestones get a badge. The iOS app follows
// the same rules (Domain/Rules/Streak.swift).

export const MILESTONES = [3, 7, 14, 30, 50, 100, 200, 365] as const;

const TITLES: Record<number, string> = {
  3: "Hat-trick!",
  7: "Week 1 complete!",
  14: "Two weeks strong!",
  30: "A month of duels!",
  50: "Half-century!",
  100: "Centurion!",
  200: "Unstoppable!",
  365: "A whole year!",
};

export const isMilestone = (n: number) => (MILESTONES as readonly number[]).includes(n);
export const milestoneTitle = (n: number) => TITLES[n] ?? `${n} days!`;
export const nextMilestone = (n: number) => MILESTONES.find((m) => m > n) ?? null;

// Each day's block in turn: lime, violet, orange, sky, so the tower is
// as colourful as the app. Badges use the same colours.
export const FLOORS = ["#c8f135", "#a594ff", "#ff8a4c", "#7fd3ff"] as const;
export const floorColor = (day: number) => FLOORS[(Math.max(1, day) - 1) % FLOORS.length]; // day is 1-based

// Today's date in India (the server's day), as YYYY-MM-DD.
export const istToday = (now = new Date()) =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Kolkata", year: "numeric", month: "2-digit", day: "2-digit" }).format(now);

// "THU" for the day `daysAgo` days before today, in India.
export function istWeekday(daysAgo: number, now = new Date()) {
  const d = new Date(now.getTime() - daysAgo * 86_400_000);
  return new Intl.DateTimeFormat("en-IN", { timeZone: "Asia/Kolkata", weekday: "short" }).format(d).toUpperCase().slice(0, 3);
}

export type Celebration =
  | { kind: "up"; from: number; to: number; fresh: boolean } // fresh: a new tower after a break
  | { kind: "fell"; from: number };

type Seen = { streak: number; day: string };

// What to show when the app sees your streak: a bigger number than it last
// celebrated (you played, here or on another device), or a tower that fell.
// Each change is shown once on this device; the answer is remembered.
export function decideCelebration(me: { id: string; streak: number; played_today: boolean }, today = istToday()): Celebration | null {
  const key = `apticks-streak-seen:${me.id}`;
  let seen: Seen | null = null;
  try {
    const raw = localStorage.getItem(key);
    seen = raw ? (JSON.parse(raw) as Seen) : null;
  } catch {
    seen = null;
  }
  const remember = () => {
    try {
      localStorage.setItem(key, JSON.stringify({ streak: me.streak, day: today } satisfies Seen));
    } catch {
      // Private mode: it may show again next time, which is fine.
    }
  };

  let c: Celebration | null = null;
  if (!seen) {
    // First time this device sees the tower: celebrate today's block.
    if (me.streak > 0 && me.played_today) c = { kind: "up", from: me.streak - 1, to: me.streak, fresh: me.streak === 1 };
  } else if (me.streak > seen.streak) {
    c = { kind: "up", from: seen.streak, to: me.streak, fresh: seen.streak === 0 };
  } else if (me.streak > 0 && me.streak < seen.streak) {
    // Missed a day, then played again: a new tower.
    c = { kind: "up", from: 0, to: me.streak, fresh: true };
  } else if (me.streak === 0 && seen.streak >= 2) {
    c = { kind: "fell", from: seen.streak };
  }
  if (c || !seen || seen.streak !== me.streak) remember();
  return c;
}

// Back on Home after the day's first duel: Tiko hops onto the streak chip
// with a short note, once a day on this device.
export function homeNoteDue(me: { id: string; streak: number; played_today: boolean }, today = istToday()) {
  if (!me.played_today || me.streak < 1) return false;
  const key = `apticks-streak-note:${me.id}`;
  try {
    if (localStorage.getItem(key) === today) return false;
    localStorage.setItem(key, today);
  } catch {
    return false;
  }
  return true;
}

export function homeNoteText(n: number) {
  const next = nextMilestone(n);
  const sub =
    n === 1
      ? "Your tower has started. See you tomorrow!"
      : next && next - n <= 3
        ? `${next - n} more ${next - n === 1 ? "day" : "days"} to your ${next}-day badge.`
        : `See you tomorrow for day ${n + 1}.`;
  return { title: `Day ${n} done! 🔥`, sub };
}

// The days of the current streak when the server can't list them (before
// 0030): consecutive days ending today, or yesterday if not played yet.
export function streakDays(streak: number, playedToday: boolean, now = new Date()) {
  const days: string[] = [];
  for (let i = 0; i < streak; i++) days.push(istToday(new Date(now.getTime() - (i + (playedToday ? 0 : 1)) * 86_400_000)));
  return days.reverse();
}

// Gentle, then firm: the phone buzzes with the animation (Android; iPhones
// ignore it in the browser, the app has real haptics).
export function buzz(pattern: number | number[]) {
  try {
    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) navigator.vibrate?.(pattern);
  } catch {
    // No vibration here.
  }
}
