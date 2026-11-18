"use client";

import { useEffect } from "react";
import { api } from "@/lib/api";
import { hasSavedSession } from "@/lib/supabase";

// A newcomer who came in through a friend's shared Daily: noted once, so
// the numbers can tell shared-link visitors from everyone else. Anyone who
// has used Apticks in this browser before is left alone.
export function ArrivalTag({ code }: { code: string }) {
  useEffect(() => {
    if (hasSavedSession()) return;
    api.noteArrival("daily", code).catch(() => {});
  }, [code]);
  return null;
}
