import type { Metadata } from "next";
import { Matchmaking } from "./matchmaking";

export const metadata: Metadata = { title: "Finding an opponent", robots: { index: false } };

export default function PlayPage() {
  return <Matchmaking />;
}
