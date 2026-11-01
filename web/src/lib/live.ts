import { useCallback, useEffect, useRef, useState } from "react";
import { api, type LiveState } from "./api";

// A live duel, refreshed about once a second. Each refresh also tells the
// server you're still here (supabase/migrations/0013_live_duels.sql: a
// player gone for 45 s forfeits the rest of the race). serverNow() is the
// server's clock, so both players count down to the same moment.
export function useLiveState(duelId: string | null, every = 1000) {
  const [state, setState] = useState<LiveState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const offset = useRef(0); // server ms minus this device's ms
  const inFlight = useRef(false);
  const alive = useRef(true);

  const refresh = useCallback(async () => {
    if (!duelId || inFlight.current) return;
    inFlight.current = true;
    const sent = Date.now();
    try {
      const s = await api.liveState(duelId);
      if (!alive.current) return;
      // The server's "now" was read about halfway through the round trip.
      offset.current = s.now_ms - (sent + Date.now()) / 2;
      setState(s);
      setError(null);
    } catch (e) {
      if (alive.current) setError((e as Error).message);
    } finally {
      inFlight.current = false;
    }
  }, [duelId]);

  // Next keeps pages mounted (hidden) after you leave, so polling stops
  // on hide and starts again when the page shows.
  useEffect(() => {
    if (!duelId) return;
    alive.current = true;
    const first = setTimeout(refresh, 0);
    const timer = setInterval(refresh, every);
    return () => {
      alive.current = false;
      clearTimeout(first);
      clearInterval(timer);
    };
  }, [duelId, every, refresh]);

  const serverNow = useCallback(() => Date.now() + offset.current, []);
  return { state, error, refresh, serverNow };
}
