import type { Subject } from "./subjects";

export const TIERS = [
  { name: "Fresher", min: 0 },
  { name: "Trainee", min: 900 },
  { name: "Analyst", min: 1100 },
  { name: "Consultant", min: 1300 },
  { name: "Lead", min: 1500 },
  { name: "Architect", min: 1700 },
] as const;

// One rating across subjects, for show (the player card, a profile's tier):
// each subject's rating weighted by the games played in it, so a subject
// never played doesn't count. Matchmaking and Ranks stay per subject.
// Before any game (or before the subjects load) it's the Aptitude rating.
export function overallRating(
  subjects: Partial<Record<Subject, { rating: number; games: number }>> | null | undefined,
  aptitude: number,
) {
  let sum = 0;
  let games = 0;
  for (const s of Object.values(subjects ?? {})) {
    if (s && s.games > 0) {
      sum += s.rating * s.games;
      games += s.games;
    }
  }
  return games > 0 ? Math.round(sum / games) : aptitude;
}

export function tierFor(rating: number) {
  let i = TIERS.length - 1;
  while (i > 0 && rating < TIERS[i].min) i--;
  const tier = TIERS[i];
  const next = TIERS[i + 1] ?? null;
  const floor = i === 0 ? 800 : tier.min;
  const progress = next ? Math.min(1, Math.max(0, (rating - floor) / (next.min - floor))) : 1;
  return { name: tier.name, min: tier.min, next, progress, toNext: next ? next.min - rating : 0 };
}

// 108000 -> "1:48"
export function clock(ms: number) {
  const total = Math.max(0, Math.round(ms / 1000));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

export function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

export function signed(n: number) {
  return n > 0 ? `+${n}` : n < 0 ? `−${Math.abs(n)}` : "±0";
}

export function greeting(date = new Date()) {
  const h = date.getHours();
  return h < 5 ? "Up late" : h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening";
}

// Time left until the daily challenge resets at midnight IST.
export function untilIstMidnight(nowMs: number) {
  const IST = 5.5 * 3_600_000;
  const DAY = 86_400_000;
  const left = DAY - ((nowMs + IST) % DAY);
  const s = Math.floor(left / 1000);
  const hh = Math.floor(s / 3600);
  const mm = Math.floor((s % 3600) / 60);
  return hh > 0 ? `${hh}h ${String(mm).padStart(2, "0")}m` : `${Math.max(mm, 1)}m`;
}

export function batch(gradYear: number | null) {
  return gradYear ? `Batch ’${String(gradYear).slice(2)}` : null;
}

// "TCS NQT · Infosys · Wipro +4": a topic can be on many companies' tests.
export function companyList(companies: string[], shown = 3) {
  const more = companies.length - shown;
  return companies.slice(0, shown).join(" · ") + (more > 0 ? ` +${more}` : "");
}

export function siteUrl(path = "") {
  return (process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000") + path;
}

// For a challenge you haven't played yet: no score to beat.
export function inviteShareText(name: string, code: string, subject: Subject = "aptitude") {
  if (subject === "english") {
    return `${name} challenged you to an English duel on Apticks. Same 5 questions for both of you: vocabulary, grammar and usage. About 3 minutes, no sign-up: ${siteUrl(`/c/${code}`)}`;
  }
  if (subject === "coding") {
    return `${name} challenged you to a coding duel on Apticks. Same 5 short programs for both of you: say what each one prints, in C, C++, Java, Python or pseudocode. About 4 minutes, no sign-up: ${siteUrl(`/c/${code}`)}`;
  }
  return `${name} challenged you to an aptitude duel on Apticks. Same 5 placement questions for both of you, about 3 minutes, no sign-up: ${siteUrl(`/c/${code}`)}`;
}

// For a live room: the friend joins and you play at the same time.
export function liveInviteText(name: string, code: string, subject: Subject = "aptitude") {
  if (subject === "english") {
    return `${name} wants a live English duel with you on Apticks: the same 5 questions at the same time, vocabulary, grammar and usage. About 3 minutes. Join here: ${siteUrl(`/c/${code}`)}`;
  }
  if (subject === "coding") {
    return `${name} wants a live coding duel with you on Apticks: the same 5 short programs at the same time, say what each one prints. C, C++, Java, Python or pseudocode, about 4 minutes. Join here: ${siteUrl(`/c/${code}`)}`;
  }
  return `${name} wants to duel you live on Apticks: the same 5 placement aptitude questions at the same time, about 3 minutes. Join here: ${siteUrl(`/c/${code}`)}`;
}

// 🟩🟩🟥🟩🟩: right or wrong per question, never which question.
export function answerGrid(grid: boolean[]) {
  return grid.map((ok) => (ok ? "🟩" : "🟥")).join("");
}

// "14 Nov" for a YYYY-MM-DD day.
export function shortDay(day: string) {
  const [y, m, d] = day.split("-").map(Number);
  return new Date(y, m - 1, d).toLocaleDateString("en-IN", { day: "numeric", month: "short" });
}

// The Daily result, Wordle-style: a grid that gives nothing away, and a
// link that says who sent it.
export function dailyShareText(r: { day: string; correct: number; total_ms: number; grid: boolean[]; streak: number; code: string }) {
  return [
    `Apticks Daily · ${shortDay(r.day)}`,
    `${answerGrid(r.grid)}  ${r.correct}/5 · ${clock(r.total_ms)}`,
    ...(r.streak >= 2 ? [`🔥 ${r.streak}-day streak`] : []),
    "",
    `Same 5 placement questions for everyone today. Can you beat me? ${siteUrl(`/d/${r.code}`)}`,
  ].join("\n");
}

export function challengeShareText(name: string, correct: number, ms: number, code: string, subject: Subject = "aptitude") {
  const what = {
    aptitude: "5 placement aptitude questions, 3 minutes",
    coding: "5 short programs, say what each one prints, 4 minutes",
    english: "5 English questions on vocabulary and grammar, 3 minutes",
  }[subject];
  return `${name} scored ${correct}/5 in ${clock(ms)} on Apticks. Think you can beat that? ${what}: ${siteUrl(`/c/${code}`)}`;
}
