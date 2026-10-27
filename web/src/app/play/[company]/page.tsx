import type { Metadata } from "next";
import { Suspense } from "react";
import { Spinner } from "@/components/ui";
import { CompanyMatchmaking } from "./company-matchmaking";

export const metadata: Metadata = { title: "Company practice", robots: { index: false } };

export default function CompanyPlayPage({ params }: PageProps<"/play/[company]">) {
  return (
    <Suspense fallback={<Spinner label="Loading" />}>
      <CompanyMatchmaking params={params} />
    </Suspense>
  );
}
