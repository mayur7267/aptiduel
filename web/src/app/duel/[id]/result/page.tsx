import type { Metadata } from "next";
import { Suspense } from "react";
import { Spinner } from "@/components/ui";
import { DuelResult } from "./duel-result";

export const metadata: Metadata = { title: "Result", robots: { index: false } };

export default function ResultPage({ params }: PageProps<"/duel/[id]/result">) {
  return (
    <main className="mx-auto w-full max-w-xl px-4 pt-5 pb-16">
      <Suspense fallback={<Spinner label="Loading result" />}>
        <DuelResult params={params} />
      </Suspense>
    </main>
  );
}
