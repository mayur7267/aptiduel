import type { Metadata } from "next";
import { Matchmaking } from "../matchmaking";

export const metadata: Metadata = { title: "Finding an opponent", robots: { index: false } };

// Quick Match in English. A static segment, so it wins over /play/[company].
export default function EnglishPlayPage() {
  return <Matchmaking subject="english" />;
}
