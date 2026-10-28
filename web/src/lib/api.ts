import { supabase } from "./supabase";

// Shapes returned by the database functions in supabase/migrations.

export type Player = {
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

export type Duel = {
  id: string;
  code: string;
  mode: "challenge" | "quick" | "daily";
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
  mode: "challenge" | "quick" | "daily";
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
  college: string | null;
  players: number;
  rows: BoardRow[];
  me: BoardRow | null;
};

export type Challenge = {
  code: string;
  open: boolean;
  challenger: { name: string; rating: number; college: string | null; grad_year: number | null };
  challenger_finished: boolean;
  score: number;
  correct: number;
  total_ms: number;
  accepted_count: number;
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

// Starting a match can hand back an unfinished one instead.
export type MatchStart = { duel_id: string; resumed?: boolean };

export const api = {
  createChallenge: () => rpc<{ duel_id: string; code: string }>("create_challenge"),
  quickMatch: () => rpc<MatchStart>("quick_match"),
  companyMatch: (company: string) => rpc<MatchStart>("company_match", { p_company: company }),
  dailyChallenge: () => rpc<{ duel_id: string }>("daily_challenge"),
  leaderboard: (scope: "college" | "india", limit = 50) =>
    rpc<Board>("leaderboard", { p_scope: scope, p_limit: limit }),
  joinChallenge: (code: string) => rpc<{ duel_id: string }>("join_challenge", { p_code: code }),
  shareCode: (duelId: string) => rpc<{ code: string }>("challenge_from_duel", { p_duel_id: duelId }),
  nextQuestion: (duelId: string) => rpc<QuestionView>("next_question", { p_duel_id: duelId }),
  submitAnswer: (duelId: string, qIndex: number, choice: number | null) =>
    rpc<AnswerResult>("submit_answer", { p_duel_id: duelId, p_q_index: qIndex, p_choice: choice }),
  getDuel: (duelId: string) => rpc<Duel>("get_duel", { p_duel_id: duelId }),
  getMe: () => rpc<Me>("get_me"),
  myDuels: (limit = 10) => rpc<DuelSummary[]>("my_duels", { p_limit: limit }),
  updateProfile: (name: string, collegeId: number | null, gradYear: number | null) =>
    rpc<Me>("update_profile", { p_name: name, p_college_id: collegeId, p_grad_year: gradYear }),
  deleteMe: () => rpc<void>("delete_me"),
  colleges: async () => {
    const { data, error } = await supabase().from("colleges").select("id, name").order("name");
    if (error) throw new Error(error.message);
    return data as { id: number; name: string }[];
  },
};
