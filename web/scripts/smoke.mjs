// End-to-end check of the game API against a Supabase project.
// Plays a challenge between three guest players and checks scoring,
// ratings and the anti-cheat rules.
//
// It creates real guest players, duels and answers. Point it at a test
// project (or a local `supabase start`), not the live one: on a hosted
// project it refuses to run unless SMOKE_ALLOW_REMOTE=1.
//
// Run from web/:  node scripts/smoke.mjs

import { createClient } from "@supabase/supabase-js";
import dotenv from "dotenv";

dotenv.config({ path: ".env.local", quiet: true });
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

const local = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?/.test(url ?? "");
if (!local && process.env.SMOKE_ALLOW_REMOTE !== "1") {
  console.error(
    `Refusing to run against ${url}: the smoke test writes real players and duels.\n` +
      "Use a test project or local Supabase, or set SMOKE_ALLOW_REMOTE=1 if you mean it.",
  );
  process.exit(2);
}

const client = () => createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
let failures = 0;
const check = (ok, label) => {
  console.log(`${ok ? "  ok  " : "  FAIL"} ${label}`);
  if (!ok) failures++;
};

async function rpc(c, fn, args) {
  const { data, error } = await c.rpc(fn, args);
  if (error) throw new Error(`${fn}: ${error.message}`);
  return data;
}

async function guest(name) {
  const c = client();
  const { error } = await c.auth.signInAnonymously();
  if (error) throw new Error(`Anonymous sign-in failed: ${error.message}. Is it enabled in Supabase → Authentication?`);
  await rpc(c, "update_profile", { p_name: name, p_college_id: null, p_grad_year: null });
  return c;
}

let pictureQuestions = 0;

async function play(c, duelId, choice) {
  for (;;) {
    const q = await rpc(c, "next_question", { p_duel_id: duelId });
    if (q.done) return;
    if ("correct_idx" in q) throw new Error("next_question leaked the answer");
    if (Array.isArray(q.option_figures) && q.option_figures.length === 4) pictureQuestions++;
    const r = await rpc(c, "submit_answer", { p_duel_id: duelId, p_q_index: q.q_index, p_choice: choice });
    if (r.done) return;
  }
}

const tag = Math.random().toString(36).slice(2, 6);
console.log("Guests");
const a = await guest(`Smoke A ${tag}`);
const b = await guest(`Smoke B ${tag}`);
const c = await guest(`Smoke C ${tag}`);
const before = {
  a: (await rpc(a, "get_me")).rating,
  b: (await rpc(b, "get_me")).rating,
  c: (await rpc(c, "get_me")).rating,
};
check(before.a === 1000 && before.b === 1000, "new players start at 1000");

console.log("Challenge");
const { duel_id, code } = await rpc(a, "create_challenge");
check(/^[A-Z0-9]{6}$/.test(code), `challenge code looks right (${code})`);
await play(a, duel_id, 0);
const pub = await rpc(client(), "get_challenge", { p_code: code });
check(pub?.challenger_finished === true && pub.challenger.name.startsWith("Smoke A"), "public challenge info works without signing in");

const joinB = await rpc(b, "join_challenge", { p_code: code });
check(joinB.duel_id === duel_id, "first acceptor joins the original duel");
await play(b, duel_id, 1);

const dA = await rpc(a, "get_duel", { p_duel_id: duel_id });
const dB = await rpc(b, "get_duel", { p_duel_id: duel_id });
check(dA.status === "complete", "duel is settled once both finish");
check(dA.review?.length === 5 && dA.review.every((r) => typeof r.explanation === "string"), "review shows 5 answers with explanations");
const deltaA = dA.me.rating_after - dA.me.rating_before;
const deltaB = dB.me.rating_after - dB.me.rating_before;
check(Math.abs(deltaA + deltaB) <= 1, `ratings move in opposite directions (A ${deltaA}, B ${deltaB})`);
const winnerA = dA.me.score > dB.me.score || (dA.me.score === dB.me.score && dA.me.total_ms < dB.me.total_ms);
check(dA.me.score === dA.opponent.score || (winnerA ? deltaA > 0 : deltaA < 0) || dA.me.total_ms === dB.me.total_ms, "the winner gains rating");

console.log("Group link (third player)");
const ratingABeforeC = (await rpc(a, "get_me")).rating;
const joinC = await rpc(c, "join_challenge", { p_code: code });
check(joinC.duel_id !== duel_id, "a later acceptor gets their own copy");
await play(c, joinC.duel_id, 2);
const dC = await rpc(c, "get_duel", { p_duel_id: joinC.duel_id });
check(dC.opponent?.is_replay === true && dC.opponent.score === dA.me.score, "they face the challenger's recorded run");
check((await rpc(a, "get_me")).rating === ratingABeforeC, "replays don't change the challenger's rating");
const share = await rpc(c, "challenge_from_duel", { p_duel_id: joinC.duel_id });
check(/^[A-Z0-9]{6}$/.test(share.code) && share.code !== code, "an acceptor can share their own score as a new link");

console.log("Rating farming");
const rematch = await rpc(a, "create_challenge");
await play(a, rematch.duel_id, 1);
await rpc(b, "join_challenge", { p_code: rematch.code });
await play(b, rematch.duel_id, 0);
const dRematch = await rpc(a, "get_duel", { p_duel_id: rematch.duel_id });
check(
  dRematch.me.rating_after === dRematch.me.rating_before &&
    dRematch.opponent.rating_after === dRematch.opponent.rating_before,
  "a second challenge between the same two players on the same day is unrated",
);

console.log("Anti-cheat");
const { data: leaked } = await a.from("questions").select("correct_idx").limit(1);
check(!leaked || leaked.length === 0, "players can't read the answer key");
const { error: tamper } = await a.from("profiles").update({ rating: 3000 }).eq("id", (await rpc(a, "get_me")).id);
check((await rpc(a, "get_me")).rating !== 3000, `players can't edit their own rating${tamper ? "" : " (silently ignored)"}`);
const { data: dump } = await client().from("profiles").select("id, display_name").limit(1);
check(!dump || dump.length === 0, "player records can't be downloaded directly");
let badName = null;
try {
  await rpc(a, "update_profile", { p_name: "www.spam.com", p_college_id: null, p_grad_year: null });
} catch (e) {
  badName = e.message;
}
check(badName !== null, "names with links are refused");
let replay = null;
try {
  await rpc(a, "submit_answer", { p_duel_id: duel_id, p_q_index: 0, p_choice: 0 });
} catch (e) {
  replay = e.message;
}
check(replay !== null, "answers can't be resubmitted after finishing");
const stranger = await guest(`Smoke D ${tag}`);
let peek = null;
try {
  await rpc(stranger, "get_duel", { p_duel_id: duel_id });
} catch (e) {
  peek = e.message;
}
check(peek !== null, "outsiders can't open someone else's duel");

const me = await rpc(a, "get_me");
check(me.streak >= 1 && me.played_today, "playing starts a daily streak");

console.log("Quick Match");
const dRatingBefore = (await rpc(stranger, "get_me")).rating;
const ghostOwnerRatings = {
  a: (await rpc(a, "get_me")).rating,
  b: (await rpc(b, "get_me")).rating,
  c: (await rpc(c, "get_me")).rating,
};
const qm = await rpc(stranger, "quick_match");
const again = await rpc(stranger, "quick_match");
check(again.duel_id === qm.duel_id && again.resumed === true, "an unfinished quick match is resumed, not replaced");
const viaCompany = await rpc(stranger, "company_match", { p_company: "Infosys" });
check(viaCompany.duel_id === qm.duel_id && viaCompany.resumed === true, "company practice also resumes it first");
await play(stranger, qm.duel_id, 3);
const dq = await rpc(stranger, "get_duel", { p_duel_id: qm.duel_id });
check(dq.mode === "quick" && dq.opponent?.is_replay === true, "quick match races another player's recorded run");
check(
  dq.me.rating_before === dRatingBefore && dq.me.rating_after === (await rpc(stranger, "get_me")).rating,
  `the racer's rating is settled (${dq.me.rating_before} → ${dq.me.rating_after})`,
);
check(
  (await rpc(a, "get_me")).rating === ghostOwnerRatings.a &&
    (await rpc(b, "get_me")).rating === ghostOwnerRatings.b &&
    (await rpc(c, "get_me")).rating === ghostOwnerRatings.c,
  "the recorded player's rating doesn't change",
);
let joinQuick = null;
try {
  await rpc(b, "join_challenge", { p_code: (await rpc(stranger, "get_duel", { p_duel_id: qm.duel_id })).code });
} catch (e) {
  joinQuick = e.message;
}
check(joinQuick !== null, "quick match duels can't be joined by code");
check(
  Array.isArray(dq.opponent_timeline) && dq.opponent_timeline.length === 5,
  "the opponent's question-by-question timeline is sent for the live race",
);

check(pictureQuestions > 0, `duels include picture questions (${pictureQuestions} served so far)`);

console.log("Practice bots");
// Real players' recorded runs are always used first. Keep playing until
// C has seen every one that fits, at which point a bot must step in.
let qb = null;
let botDuelBefore = null;
let realRuns = 0;
for (let i = 0; i < 25; i++) {
  const m = await rpc(c, "quick_match");
  const d = await rpc(c, "get_duel", { p_duel_id: m.duel_id });
  if (d.opponent?.is_bot) {
    qb = m;
    botDuelBefore = d;
    break;
  }
  realRuns++;
  await play(c, m.duel_id, 1);
}
check(botDuelBefore !== null, `after ${realRuns} real player run(s), a bot steps in (${botDuelBefore?.opponent?.name})`);
const cBefore = (await rpc(c, "get_me")).rating;
check(botDuelBefore.opponent?.finished && botDuelBefore.opponent_timeline?.length === 5, "the bot's run is ready to race");
const botRating = botDuelBefore.opponent.rating;
await play(c, qb.duel_id, 0);
const botDuel = await rpc(c, "get_duel", { p_duel_id: qb.duel_id });
check(botDuel.opponent.rating === botRating, "the bot's rating never changes");
check(botDuel.me.rating_before === cBefore && botDuel.me.rating_after !== null, "your rating is settled against the bot");
const board = await rpc(c, "leaderboard", { p_scope: "india", p_limit: 100 });
check(!board.rows.some((r) => r.name === botDuel.opponent.name), "bots never appear on leaderboards");
const cRecent = await rpc(c, "my_duels", { p_limit: 5 });
check(cRecent.some((d) => d.opponent_is_bot === true), "recent duels mark bot opponents");

console.log("Daily challenge");
const day1 = await rpc(a, "daily_challenge");
const day2 = await rpc(a, "daily_challenge");
check(day1.duel_id === day2.duel_id, "one daily run per player per day");
await play(a, day1.duel_id, 0);
const dayB = await rpc(b, "daily_challenge");
check(dayB.duel_id !== day1.duel_id, "each player gets their own daily run");
await play(b, dayB.duel_id, 1);
const dailyA = await rpc(a, "get_duel", { p_duel_id: day1.duel_id });
check(dailyA.daily?.players >= 2 && dailyA.daily.rank >= 1, `daily rank works (#${dailyA.daily?.rank} of ${dailyA.daily?.players})`);
const meA = await rpc(a, "get_me");
check(meA.quests.daily === 1 && meA.daily_week[meA.today_idx] === true, "daily quest and week dots update");
check(dailyA.status === "complete", "a finished daily run is marked complete");
let dailyShare = null;
try {
  await rpc(a, "challenge_from_duel", { p_duel_id: day1.duel_id });
} catch (e) {
  dailyShare = e.message;
}
check(dailyShare !== null, "today's daily set can't be shared before it resets");

console.log("Leaderboards");
const india = await rpc(a, "leaderboard", { p_scope: "india", p_limit: 100 });
check(india.rows.length > 0 && india.me?.rank >= 1, `all-India board ranks players (you're #${india.me?.rank})`);
const college = await rpc(a, "leaderboard", { p_scope: "college", p_limit: 5 });
check(college.college === null && college.rows.length === 0, "college board is empty until you pick a college");
const recent = await rpc(a, "my_duels", { p_limit: 10 });
check(recent.some((d) => d.mode === "daily") && recent.every((d) => "total_ms" in d), "recent duels include daily runs");

console.log("Cleanup");
for (const p of [a, b, c, stranger]) await rpc(p, "delete_me");
const gone = await rpc(client(), "get_challenge", { p_code: code });
check(gone === null, "a deleted player's challenge link stops working");

console.log(failures ? `\n${failures} check(s) failed` : "\nAll checks passed");
process.exit(failures ? 1 : 0);
