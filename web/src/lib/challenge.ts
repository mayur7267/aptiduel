import { cache } from "react";
import type { Challenge } from "./api";
import { publicSupabase } from "./supabase";

// Server-side read of a challenge link's public info. Wrapped in
// React.cache so the page, its metadata and its share image share one
// request per render.
export const getChallenge = cache(async (code: string): Promise<Challenge | null> => {
  if (!/^[A-Za-z0-9]{4,12}$/.test(code)) return null;
  const { data, error } = await publicSupabase().rpc("get_challenge", { p_code: code });
  if (error) throw new Error(error.message);
  return (data as Challenge | null) ?? null;
});
