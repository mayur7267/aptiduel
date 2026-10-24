import type { Metadata } from "next";
import { Suspense } from "react";
import { Spinner } from "@/components/ui";
import { DuelPlay } from "./duel-play";

export const metadata: Metadata = { title: "Duel", robots: { index: false } };

export default function DuelPage({ params }: PageProps<"/duel/[id]">) {
  return (
    <main className="mx-auto flex w-full max-w-xl flex-1 flex-col px-4 pt-5 pb-8">
      <Suspense fallback={<Spinner label="Loading duel" />}>
        <DuelPlay params={params} />
      </Suspense>
    </main>
  );
}
