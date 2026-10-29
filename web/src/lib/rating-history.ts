// The profile page's rating chart and weekly change, from recent duels.
// Plain functions (no imports from the app) so they can be unit tested.

type RatedDuel = {
  created_at: string;
  is_replay: boolean;
  rating_before: number | null;
  rating_after: number | null;
};

// Rating after each rated duel, oldest first, ending at today's rating.
export function ratingHistory(duels: RatedDuel[], current: number): number[] {
  const rated = duels
    .filter((d) => d.rating_after !== null && !d.is_replay)
    .sort((a, b) => Date.parse(a.created_at) - Date.parse(b.created_at));
  const points = rated[0]?.rating_before != null ? [rated[0].rating_before] : [];
  for (const d of rated) points.push(d.rating_after as number);
  if (points[points.length - 1] !== current) points.push(current);
  return points;
}

// Rating gained or lost over the last 7 days.
export function weekChange(duels: RatedDuel[], now = Date.now()): number {
  return duels
    .filter((d) => !d.is_replay && now - Date.parse(d.created_at) < 7 * 86_400_000)
    .reduce((sum, d) => sum + (d.rating_after !== null && d.rating_before !== null ? d.rating_after - d.rating_before : 0), 0);
}
