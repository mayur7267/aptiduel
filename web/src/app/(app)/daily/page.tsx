import type { Metadata } from "next";
import { DailyStart } from "./daily-start";

export const metadata: Metadata = { title: "Daily challenge", robots: { index: false } };

export default function DailyPage() {
  return (
    <main className="mx-auto w-full max-w-xl px-4 pt-10">
      <DailyStart />
    </main>
  );
}
