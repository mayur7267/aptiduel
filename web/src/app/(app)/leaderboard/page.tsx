import type { Metadata } from "next";
import { LeaderboardClient } from "./leaderboard-client";

export const metadata: Metadata = { title: "Leaderboard", robots: { index: false } };

export default function LeaderboardPage() {
  return <LeaderboardClient />;
}
