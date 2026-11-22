import type { Metadata } from "next";
import { StreakClient } from "./streak-client";

export const metadata: Metadata = { title: "Your streak", robots: { index: false } };

export default function StreakPage() {
  return <StreakClient />;
}
