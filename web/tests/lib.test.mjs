// Unit tests for the plain helpers in src/lib. Uses Node's built-in test
// runner, which loads the TypeScript files directly.
//
// Run from web/:  npm test

import assert from "node:assert/strict";
import { test } from "node:test";
import { COMPANIES, companyBySlug } from "../src/lib/companies.ts";
import {
  batch,
  challengeShareText,
  clock,
  initials,
  inviteShareText,
  signed,
  tierFor,
  untilIstMidnight,
} from "../src/lib/format.ts";

test("tierFor names the tier and the gap to the next", () => {
  assert.deepEqual(
    { ...tierFor(1000), next: tierFor(1000).next?.name },
    { name: "Trainee", min: 900, next: "Analyst", progress: 0.5, toNext: 100 },
  );
  assert.equal(tierFor(850).name, "Fresher");
  assert.equal(tierFor(100).progress, 0);
  const top = tierFor(2400);
  assert.equal(top.name, "Architect");
  assert.equal(top.next, null);
  assert.equal(top.toNext, 0);
});

test("clock shows minutes and seconds, never negative", () => {
  assert.equal(clock(108_000), "1:48");
  assert.equal(clock(5_400), "0:05");
  assert.equal(clock(-200), "0:00");
});

test("signed uses a real minus sign", () => {
  assert.equal(signed(12), "+12");
  assert.equal(signed(-7), "−7");
  assert.equal(signed(0), "±0");
});

test("initials", () => {
  assert.equal(initials("Sneha G."), "SG");
  assert.equal(initials("mayur"), "MA");
  assert.equal(initials("   "), "?");
});

test("untilIstMidnight counts down to midnight in India", () => {
  assert.equal(untilIstMidnight(Date.UTC(2026, 9, 28, 18, 30)), "24h 00m"); // 00:00 IST
  assert.equal(untilIstMidnight(Date.UTC(2026, 9, 28, 17, 0)), "1h 30m"); // 22:30 IST
  assert.equal(untilIstMidnight(Date.UTC(2026, 9, 28, 18, 29, 30)), "1m"); // 30 s left
});

test("batch and share text", () => {
  assert.equal(batch(2027), "Batch ’27");
  assert.equal(batch(null), null);
  const text = challengeShareText("Asha", 4, 95_000, "ABC123");
  assert.match(text, /^Asha scored 4\/5 in 1:35 on Apticks\./);
  assert.match(text, /\/c\/ABC123$/);
  const invite = inviteShareText("Asha", "XYZ789");
  assert.match(invite, /^Asha challenged you to an aptitude duel on Apticks\./);
  assert.doesNotMatch(invite, /scored/);
  assert.match(invite, /\/c\/XYZ789$/);
});

test("companies have unique slugs and resolve by slug", () => {
  assert.equal(new Set(COMPANIES.map((c) => c.slug)).size, COMPANIES.length);
  assert.equal(companyBySlug("tcs-nqt")?.name, "TCS NQT");
  assert.equal(companyBySlug("nope"), null);
});

test("rating history runs oldest to newest and ends at today's rating", async () => {
  const { ratingHistory, weekChange } = await import("../src/lib/rating-history.ts");
  const now = Date.parse("2026-10-30T12:00:00Z");
  const duels = [
    { created_at: "2026-10-29T10:00:00Z", is_replay: false, rating_before: 1164, rating_after: 1180 },
    { created_at: "2026-10-20T10:00:00Z", is_replay: false, rating_before: 1150, rating_after: 1164 },
    { created_at: "2026-10-28T10:00:00Z", is_replay: true, rating_before: null, rating_after: null },
  ];
  assert.deepEqual(ratingHistory(duels, 1180), [1150, 1164, 1180]);
  assert.deepEqual(ratingHistory([], 1000), [1000]);
  assert.equal(weekChange(duels, now), 16);
});

// "Add to Home screen": stay quiet for two weeks after they say no.
test("install prompt stays quiet for 14 days after a no", async () => {
  const { recentlyDismissed, rememberDismissed } = await import("../src/lib/install.ts");
  const store = new Map();
  globalThis.localStorage = { getItem: (k) => store.get(k) ?? null, setItem: (k, v) => store.set(k, v) };
  const day = 86_400_000;
  const t0 = Date.UTC(2026, 10, 7);
  assert.equal(recentlyDismissed(t0), false); // never asked
  rememberDismissed(t0);
  assert.equal(recentlyDismissed(t0 + 13 * day), true);
  assert.equal(recentlyDismissed(t0 + 15 * day), false);
  // Private windows can throw; it should just ask again, not crash.
  globalThis.localStorage = { getItem() { throw new Error("blocked"); }, setItem() { throw new Error("blocked"); } };
  assert.equal(recentlyDismissed(t0), false);
  assert.doesNotThrow(() => rememberDismissed(t0));
  delete globalThis.localStorage;
});

test("daily calendar: IST days, the week from home, a Monday-first month", async () => {
  const { addDays, istKey, monthGrid, monthOf, runs, shiftMonth, weekDays } = await import("../src/lib/daily-calendar.ts");
  // 11 Nov 2026, 23:30 IST is still the 11th; 00:30 IST is the 12th.
  assert.equal(istKey(Date.parse("2026-11-11T18:00:00Z")), "2026-11-11");
  assert.equal(istKey(Date.parse("2026-11-11T19:00:00Z")), "2026-11-12");
  assert.equal(addDays("2026-03-01", -1), "2026-02-28");
  // Wednesday (2) with Monday and Wednesday done.
  const now = Date.parse("2026-11-11T06:00:00Z");
  assert.deepEqual(weekDays([true, false, true, false, false, false, false], 2, now), ["2026-11-09", "2026-11-11"]);
  assert.deepEqual(shiftMonth({ year: 2026, month: 0 }, -1), { year: 2025, month: 11 });
  assert.deepEqual(shiftMonth({ year: 2026, month: 11 }, 1), { year: 2027, month: 0 });
  // November 2026 starts on a Sunday: six blanks, then the 1st.
  const weeks = monthGrid(monthOf("2026-11-11"), new Set(["2026-11-09"]), "2026-11-11");
  assert.equal(weeks.length, 6);
  assert.equal(weeks.flat().length, 42);
  assert.equal(weeks[0][5].day, null);
  assert.equal(weeks[0][6].day, 1);
  const cells = weeks.flat();
  assert.equal(cells.find((c) => c.key === "2026-11-09")?.done, true);
  assert.equal(cells.find((c) => c.key === "2026-11-11")?.today, true);
  assert.equal(cells.find((c) => c.key === "2026-11-12")?.future, true);
  assert.equal(cells.filter((c) => c.day !== null).length, 30);
});

test("daily calendar runs: in a row up to today or yesterday, best run, total", async () => {
  const { runs } = await import("../src/lib/daily-calendar.ts");
  const days = new Set(["2026-10-30", "2026-10-31", "2026-11-01", "2026-11-09", "2026-11-10"]);
  // Today's not done yet: the run up to yesterday still counts.
  assert.deepEqual(runs(days, "2026-11-11"), { current: 2, best: 3, total: 5 });
  assert.deepEqual(runs(new Set([...days, "2026-11-11"]), "2026-11-11"), { current: 3, best: 3, total: 6 });
  assert.deepEqual(runs(days, "2026-11-12"), { current: 0, best: 3, total: 5 });
  assert.deepEqual(runs(new Set(), "2026-11-11"), { current: 0, best: 0, total: 0 });
});
