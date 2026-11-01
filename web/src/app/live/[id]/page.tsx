import type { Metadata } from "next";
import { Suspense } from "react";
import { Spinner } from "@/components/ui";
import { LiveStart } from "./live-start";

export const metadata: Metadata = { title: "Live duel", robots: { index: false } };

export default function LivePage({ params }: PageProps<"/live/[id]">) {
  return (
    <main className="mx-auto flex w-full max-w-xl flex-1 flex-col px-4 pt-5 pb-8">
      <Suspense fallback={<Spinner label="Loading duel" />}>
        <LiveStart params={params} />
      </Suspense>
    </main>
  );
}
