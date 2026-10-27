"use client";

import { notFound } from "next/navigation";
import { use } from "react";
import { companyBySlug } from "@/lib/companies";
import { Matchmaking } from "../matchmaking";

export function CompanyMatchmaking({ params }: { params: Promise<{ company: string }> }) {
  const company = companyBySlug(use(params).company);
  if (!company) notFound();
  return <Matchmaking company={company} />;
}
