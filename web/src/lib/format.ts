export const TIERS = [
  { name: "Fresher", min: 0 },
  { name: "Trainee", min: 900 },
  { name: "Analyst", min: 1100 },
  { name: "Consultant", min: 1300 },
  { name: "Lead", min: 1500 },
  { name: "Architect", min: 1700 },
] as const;

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

export function siteUrl(path = "") {
  return (process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000") + path;
}

// For a challenge you haven't played yet: no score to beat.
export function inviteShareText(name: string, code: string) {
  return `${name} challenged you to an aptitude duel on Apticks. Same 5 placement questions for both of you, about 3 minutes, no sign-up: ${siteUrl(`/c/${code}`)}`;
}

export function challengeShareText(name: string, correct: number, ms: number, code: string) {
  return `${name} scored ${correct}/5 in ${clock(ms)} on Apticks. Think you can beat that? 5 placement aptitude questions, 3 minutes: ${siteUrl(`/c/${code}`)}`;
}
