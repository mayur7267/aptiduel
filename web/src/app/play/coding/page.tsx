import type { Metadata } from "next";
import { Matchmaking } from "../matchmaking";

export const metadata: Metadata = { title: "Finding an opponent", robots: { index: false } };

// Quick Match in Coding. A static segment, so it wins over /play/[company].
export default function CodingPlayPage() {
  return <Matchmaking subject="coding" />;
}
