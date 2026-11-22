import { supabase } from "./supabase";
import type { Code, Subject } from "./subjects";

// Shapes returned by the database functions in supabase/migrations.

export type Player = {
  id?: string; // for linking to their profile
  seat: 1 | 2;
  name: string;
  rating: number;
  college: string | null;
  is_bot: boolean;
  tagline: string | null; // bots only
  score: number;
  correct: number;
  total_ms: number;
  answered: number;
  finished: boolean;
  is_replay: boolean;
  rating_before: number | null;
  rating_after: number | null;
};

export type ReviewItem = {
  q_index: number;
  section: string;
  topic: string;
  companies: string[]; // company test patterns this topic is on
  body: string;
  figure: string | null;
  code?: Code | null; // coding questions: the program in each language
  options: string[];
  option_figures: string[] | null;
  correct_idx: number;
  chosen_idx: number | null;
  is_correct: boolean;
  points: number;
  ms: number;
  explanation: string;
  opp_correct: boolean | null;
};

export type DuelMode = "challenge" | "quick" | "daily" | "live";

export type Duel = {
  id: string;
  code: string;
  mode: DuelMode;
  subject?: Subject; // missing before 0022_subjects: Aptitude
  company?: string | null; // set on company practice duels (and challenges made from them)
  status: "open" | "complete";
  is_creator: boolean;
  me: Player;
  opponent: Player | null;
  // The opponent's run, question by question, once it's finished. Used to
  // replay them racing you during the duel.
  opponent_timeline: { q_index: number; ms: number; correct: boolean; points: number }[] | null;
  // Your own results so far (no answers revealed), for restoring after a refresh.
  my_answers: { q_index: number; correct: boolean }[] | null;
  review: ReviewItem[] | null;
  daily: { rank: number; players: number } | null;
};

export type QuestionView =
  | { done: true; score: number }
  | {
      done: false;
      q_index: number;
      total: number;
      section: string;
      topic: string;
      companies: string[]; // company test patterns this topic is on
      difficulty: 1 | 2 | 3;
      body: string;
      figure: string | null; // SVG shown with the question
      code?: Code | null; // coding questions: the program in each language
      options: string[];
      option_figures: string[] | null; // SVG per option for picture questions
      time_limit_ms: number;
      remaining_ms: number;
      score: number;
    };

export type AnswerResult = {
  correct: boolean;
  correct_idx: number;
  points: number;
  score: number;
  elapsed_ms: number;
  done: boolean;
};

export type Me = {
  id: string;
  name: string;
  rating: number;
  games_played: number;
  wins: number;
  streak: number;
  streak_best: number;
  played_today: boolean;
  college_id: number | null;
  college: string | null;
  grad_year: number | null;
  college_rank: number | null;
  today_idx: number; // 0 = Monday, IST
  daily_week: boolean[]; // daily challenge done, Monday to Sunday
  quests: { daily: number; quick_wins: number; accepted: number };
};

export type DuelSummary = {
  id: string;
  mode: DuelMode;
  subject?: Subject;
  company?: string | null;
  status: string;
  created_at: string;
  code: string | null; // set on challenges you started
  seat: 1 | 2;
  is_replay: boolean;
  score: number;
  correct: number;
  total_ms: number;
  finished: boolean;
  rating_before: number | null;
  rating_after: number | null;
  opponent_name: string | null;
  opponent_is_bot: boolean;
  opponent_college: string | null;
  opponent_is_replay: boolean | null;
  opponent_score: number | null;
  opponent_total_ms: number | null;
  opponent_finished: boolean | null;
};

export type BoardRow = {
  id?: string; // for linking to their profile
  rank: number;
  name: string;
  rating: number;
  college: string | null;
  grad_year: number | null;
  week_delta: number;
  is_me: boolean;
};

export type Board = {
  scope: "college" | "india";
  subject?: Subject; // 0025_subject_ranks; missing before it (Aptitude)
  college: string | null;
  players: number;
  rows: BoardRow[];
  me: BoardRow | null;
};

export type Challenge = {
  code: string;
  open: boolean;
  live?: boolean; // a live room (create_room) rather than a recorded challenge
  started?: boolean; // live: the duel has begun
  full?: boolean; // live: both seats are taken
  my_seat?: 1 | 2 | null; // your seat, when you're in it (needs your session)
  subject?: Subject; // 0023_room_subjects; missing before it (Aptitude)
  challenger: { name: string; rating: number; college: string | null; grad_year: number | null };
  challenger_finished: boolean;
  score: number;
  correct: number;
  total_ms: number;
  accepted_count: number;
};

// The challenger's own view of their challenge link. null for anyone else.
export type ChallengeStatus = {
  duel_id: string;
  code: string;
  open: boolean;
  me: { name: string; finished: boolean; score: number; correct: number; total_ms: number };
  friends: {
    duel_id: string; // their run: the original duel for the first friend, a copy for later ones
    name: string;
    college: string | null;
    finished: boolean;
    score: number;
    correct: number;
    total_ms: number;
  }[];
};

let sessionReady: Promise<void> | null = null;

// Every visitor plays as a guest first: an anonymous Supabase account
// is created on first use and kept in this browser.
export function ensureSession() {
  sessionReady ??= (async () => {
    const auth = supabase().auth;
    const { data } = await auth.getSession();
    if (data.session) return;
    const { error } = await auth.signInAnonymously();
    if (error) {
      sessionReady = null;
      throw new Error(error.message);
    }
  })();
  return sessionReady;
}

// Forget the session after signing out or deleting the account. The next
// call starts a fresh guest.
export function resetSession() {
  sessionReady = null;
}

async function rpc<T>(fn: string, args?: Record<string, unknown>, retried = false): Promise<T> {
  await ensureSession();
  const { data, error } = await supabase().rpc(fn, args);
  // The account was deleted on another device: drop its session here
  // too and carry on as a fresh guest.
  if (error?.message === "This account was deleted." && !retried) {
    await supabase().auth.signOut({ scope: "local" });
    resetSession();
    return rpc<T>(fn, args, true);
  }
  if (error) throw new Error(error.message);
  return data as T;
}

// The placement test you're preparing for (my_drive), with your
// practice on that company's topics in the last 30 days.
export type Drive =
  | { company: null }
  | {
      company: string;
      drive_on: string; // YYYY-MM-DD
      days_left: number; // negative once it's past
      answered: boolean; // told us how it went
      cleared: "yes" | "no" | "skipped" | null;
      practised: number;
      accuracy: number | null; // percent right
      weak_topics: string[];
    };

// Anyone's public profile (get_profile). vs_me is your own record
// against them, when you're signed in and it isn't you.
export type Profile = {
  id: string;
  name: string;
  college: string | null;
  grad_year: number | null;
  rating: number;
  games_played: number;
  wins: number;
  streak: number;
  streak_best: number;
  is_bot: boolean;
  tagline: string | null;
  is_me: boolean;
  joined: string;
  college_rank: number | null;
  recent: ("W" | "L" | "D")[]; // newest first
  vs_me: { played: number; wins: number; losses: number } | null;
  subjects?: Subjects; // 0025_subject_ranks; missing before it
};

// A live friend duel as of now (live_state): the lobby, the countdown,
// then a race where both players' progress shows as it happens. Times are
// server epoch ms; now_ms lets the screen line its clock up with the
// server's.
export type LivePlayer = {
  id?: string;
  seat: 1 | 2;
  name: string;
  rating: number;
  college: string | null;
  present: boolean; // their screen checked in during the last 15 s
  answered: number; // questions answered so far
  correct: number;
  score: number;
  finished: boolean;
  marks: boolean[]; // right or wrong, question by question
};

export type LiveState = {
  id: string;
  code: string;
  status: "waiting" | "starting" | "playing" | "done" | "async" | "closed";
  is_host: boolean;
  now_ms: number;
  starts_at_ms: number | null; // when the first question opens for both
  me: LivePlayer;
  opponent: LivePlayer | null;
  rematch_id: string | null;
  subject?: Subject; // 0023_room_subjects; missing before it (Aptitude)
};

export type ShareKind = "daily" | "story" | "challenge" | "campus";
export type ShareChannel = "whatsapp" | "share" | "copy" | "download";

// The public side of a shared Daily run: right or wrong per question,
// never the questions themselves (daily_share in 0021_share_cards.sql).
export type DailyShare = {
  name: string;
  day: string; // YYYY-MM-DD, IST
  today: boolean;
  correct: number;
  score: number;
  total_ms: number;
  grid: boolean[];
};

// The Streak Tower page (my_streak, 0030_streak_tower.sql): days are the
// India dates you played in the last 120 days.
export type StreakInfo = {
  streak: number;
  best: number;
  played_today: boolean;
  days: string[];
  college: string | null;
  college_top: { name: string; streak: number; is_me: boolean }[];
};

// Starting a match can hand back an unfinished one instead.
export type MatchStart = { duel_id: string; resumed?: boolean };

// Your rating and games in each subject (my_subjects).
// English is missing until 0024_english is applied.
export type Subjects = Record<Exclude<Subject, "english">, { rating: number; games: number }> & { english?: { rating: number; games: number } };

// Before a migration is applied its new functions don't exist yet.
const missingFunction = (e: unknown) => e instanceof Error && /Could not find the function/i.test(e.message);

export const api = {
  createChallenge: () => rpc<{ duel_id: string; code: string }>("create_challenge"),
  // Aptitude uses the original call, so it works with or without 0022.
  quickMatch: (subject: Subject = "aptitude") =>
    subject === "aptitude" ? rpc<MatchStart>("quick_match") : rpc<MatchStart>("quick_match", { p_subject: subject }),
  // null until 0022_subjects is live: the Coding tab stays hidden.
  mySubjects: () => rpc<Subjects>("my_subjects").catch((e) => (missingFunction(e) ? null : Promise.reject(e))),
  companyMatch: (company: string) => rpc<MatchStart>("company_match", { p_company: company }),
  dailyChallenge: () => rpc<{ duel_id: string }>("daily_challenge"),
  // The IST days you finished the Daily, oldest first (0016_daily_calendar.sql).
  dailyDays: () => rpc<string[]>("daily_days"),
  // A board per subject (0025_subject_ranks). Aptitude uses the original
  // call, so it works with or without 0025.
  leaderboard: (scope: "college" | "india", limit = 50, subject: Subject = "aptitude") =>
    subject === "aptitude"
      ? rpc<Board>("leaderboard", { p_scope: scope, p_limit: limit })
      : rpc<Board>("leaderboard", { p_scope: scope, p_limit: limit, p_subject: subject }),
  // p_client 2: this app shows code, so Coding duels are open to it
  // (0023_room_subjects; older apps get a message to update instead).
  joinChallenge: (code: string) =>
    rpc<{ duel_id: string }>("join_challenge", { p_code: code, p_client: 2 }).catch((e) =>
      missingFunction(e) ? rpc<{ duel_id: string }>("join_challenge", { p_code: code }) : Promise.reject(e),
    ),
  // Live friend duels (supabase/migrations/0013_live_duels.sql). Opening
  // and joining need a saved account.
  getChallenge: (code: string) => rpc<Challenge | null>("get_challenge", { p_code: code }),
  // A room in a subject (0023_room_subjects). Aptitude uses the original
  // call, so it works with or without 0023.
  createRoom: (subject: Subject = "aptitude") =>
    subject === "aptitude"
      ? rpc<{ duel_id: string; code: string }>("create_room")
      : rpc<{ duel_id: string; code: string }>("create_room", { p_subject: subject }),
  // The host changes the subject until the friend joins.
  setRoomSubject: (duelId: string, subject: Subject) =>
    rpc<{ subject: Subject }>("set_room_subject", { p_duel_id: duelId, p_subject: subject }),
  joinRoom: (code: string) =>
    rpc<{ duel_id: string; mode: "live" | "challenge" }>("join_room", { p_code: code, p_client: 2 }).catch((e) =>
      missingFunction(e)
        ? rpc<{ duel_id: string; mode: "live" | "challenge" }>("join_room", { p_code: code })
        : Promise.reject(e),
    ),
  liveState: (duelId: string) => rpc<LiveState>("live_state", { p_duel_id: duelId }),
  livePlayNow: (duelId: string) => rpc<{ duel_id: string }>("live_play_now", { p_duel_id: duelId }),
  liveCancel: (duelId: string) => rpc<void>("live_cancel", { p_duel_id: duelId }),
  liveRematch: (duelId: string) => rpc<{ duel_id: string; code: string }>("live_rematch", { p_duel_id: duelId }),
  challengeStatus: (code: string) => rpc<ChallengeStatus | null>("challenge_status", { p_code: code }),
  shareCode: (duelId: string) => rpc<{ code: string }>("challenge_from_duel", { p_duel_id: duelId }),
  // Sharing (0021_share_cards.sql): count taps on share buttons, and tag a
  // newcomer who came in through a shared Daily or story link.
  logShare: (kind: ShareKind, channel: ShareChannel, duelId: string | null) =>
    rpc<void>("log_share", { p_kind: kind, p_channel: channel, p_duel_id: duelId }),
  noteArrival: (via: "daily" | "story" | "campus", code: string | null = null) =>
    rpc<void>("note_arrival", { p_via: via, p_code: code }),
  nextQuestion: (duelId: string) => rpc<QuestionView>("next_question", { p_duel_id: duelId }),
  submitAnswer: (duelId: string, qIndex: number, choice: number | null) =>
    rpc<AnswerResult>("submit_answer", { p_duel_id: duelId, p_q_index: qIndex, p_choice: choice }),
  getDuel: (duelId: string) => rpc<Duel>("get_duel", { p_duel_id: duelId }),
  getMe: () => rpc<Me>("get_me"),
  getProfile: (id: string) => rpc<Profile | null>("get_profile", { p_id: id }),
  myDrive: () => rpc<Drive>("my_drive"),
  setDrive: (company: string | null, driveOn: string | null) => rpc<Drive>("set_drive", { p_company: company, p_drive_on: driveOn }),
  submitDriveResult: (cleared: "yes" | "no" | "skipped", difficulty: "easier" | "same" | "harder" | null) =>
    rpc<Drive>("submit_drive_result", { p_cleared: cleared, p_difficulty: difficulty }),
  // Every subject (my_duels itself only lists Aptitude, for the apps already out).
  myDuels: (limit = 10) =>
    rpc<DuelSummary[]>("my_duels_all", { p_limit: limit }).catch((e) =>
      missingFunction(e) ? rpc<DuelSummary[]>("my_duels", { p_limit: limit }) : Promise.reject(e),
    ),
  updateProfile: (name: string, collegeId: number | null, gradYear: number | null) =>
    rpc<Me>("update_profile", { p_name: name, p_college_id: collegeId, p_grad_year: gradYear }),
  // From a campus link (0029_campus_links): your college becomes this one.
  // Before 0029 it goes through update_profile, keeping your name and year.
  joinCollege: (collegeId: number) =>
    rpc<Me>("join_college", { p_id: collegeId }).catch(async (e) => {
      if (!missingFunction(e)) throw e;
      const me = await api.getMe();
      return api.updateProfile(me.name, collegeId, me.grad_year);
    }),
  deleteMe: () => rpc<void>("delete_me"),
  // Before 0030 the days are the current streak's, worked out from get_me.
  myStreak: () =>
    rpc<StreakInfo>("my_streak").catch(async (e) => {
      if (!missingFunction(e)) throw e;
      const me = await api.getMe();
      const { streakDays } = await import("./streak");
      return { streak: me.streak, best: me.streak_best, played_today: me.played_today, days: streakDays(me.streak, me.played_today), college: me.college, college_top: [] };
    }),
  // Emailed to the team (supabase/functions/feedback-mail).
  submitFeedback: (kind: "bug" | "idea" | "question", message: string, email: string | null, context: Record<string, unknown>) =>
    rpc<void>("submit_feedback", { p_kind: kind, p_message: message, p_email: email, p_platform: "web", p_context: context }),
  colleges: async () => {
    const { data, error } = await supabase().from("colleges").select("id, name").order("name");
    if (error) throw new Error(error.message);
    return data as { id: number; name: string }[];
  },
  // Colleges from all over the world (0027), best match first; country is
  // a hint (the player's own). Before 0027 the server has no search, so
  // the old list is filtered here instead.
  searchColleges: async (query: string, country: string | null): Promise<CollegeHit[]> => {
    try {
      return await rpc<CollegeHit[]>("search_colleges", { p_query: query, p_limit: 20, p_country: country });
    } catch (e) {
      if (!missingFunction(e)) throw e;
      const q = query.trim().toLowerCase();
      const list = await api.colleges();
      return list
        .filter((c) => c.name.toLowerCase().includes(q))
        .slice(0, 20)
        .map((c) => ({ ...c, city: null, country: null, players: 0 }));
    }
  },
  // A college that isn't on the list yet; returns its id (or the id of the
  // same college if someone added it already).
  addCollege: (name: string, city: string | null, country: string) =>
    rpc<number>("add_college", { p_name: name, p_city: city, p_country: country }).catch((e) =>
      Promise.reject(missingFunction(e) ? new Error("Adding a college opens soon. Pick “Other college” for now.") : e),
    ),
};

export type CollegeHit = { id: number; name: string; city: string | null; country: string | null; players: number };
