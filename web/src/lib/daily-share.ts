import { cache } from "react";
import type { DailyShare } from "./api";
import { publicSupabase } from "./supabase";

// Server-side read of a shared Daily run (the /d/<code> page). Wrapped in
// React.cache so the page, its metadata and its share image share one
// request per render.
export const getDailyShare = cache(async (code: string): Promise<DailyShare | null> => {
  if (!/^[A-Za-z0-9]{4,12}$/.test(code)) return null;
  const { data, error } = await publicSupabase().rpc("daily_share", { p_code: code });
  if (error) throw new Error(error.message);
  return (data as DailyShare | null) ?? null;
});
