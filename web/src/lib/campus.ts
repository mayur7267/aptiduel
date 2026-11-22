import { cache } from "react";
import { publicSupabase } from "./supabase";

// Campus links (0029_campus_links.sql): /join/<college id>-<name> puts a
// student straight onto their college's board.

export type CollegeCard = {
  id: number;
  name: string;
  city: string | null;
  country: string | null;
  players: number;
  top: { name: string; rating: number }[];
};

// /join/57-delhi-technological-university: the id is what counts, the
// name is there so the link reads well in a WhatsApp group.
export function campusPath(id: number, name: string) {
  const slug = name
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48)
    .replace(/-+$/, "");
  return `/join/${id}${slug ? `-${slug}` : ""}`;
}

export function campusId(param: string) {
  const m = /^(\d{1,9})(?:-|$)/.exec(decodeURIComponent(param));
  return m ? Number(m[1]) : null;
}

// Server-side read for the join page, its metadata and its share image
// (one request per render). Before 0029 there's no college_card, so the
// college is read from the list instead, without the players.
export const getCollegeCard = cache(async (id: number): Promise<CollegeCard | null> => {
  const db = publicSupabase();
  const { data, error } = await db.rpc("college_card", { p_id: id });
  if (!error) return (data as CollegeCard | null) ?? null;
  if (!/Could not find the function/i.test(error.message)) throw new Error(error.message);
  const { data: row } = await db.from("colleges").select("id, name").eq("id", id).maybeSingle();
  return row ? { id: row.id, name: row.name, city: null, country: null, players: 0, top: [] } : null;
});
