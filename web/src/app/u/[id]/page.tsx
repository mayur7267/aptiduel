import type { Metadata } from "next";
import { Suspense } from "react";
import { Spinner } from "@/components/ui";
import { PublicProfile } from "./public-profile";

export const metadata: Metadata = { title: "Player", robots: { index: false } };

export default function PlayerPage({ params }: PageProps<"/u/[id]">) {
  return (
    <main className="mx-auto w-full max-w-xl px-4 pt-5 pb-16">
      <Suspense fallback={<Spinner label="Loading player" />}>
        <PublicProfile params={params} />
      </Suspense>
    </main>
  );
}
