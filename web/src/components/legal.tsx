import Link from "next/link";
import type { ReactNode } from "react";
import { CONTACT_EMAIL } from "@/lib/contact";
import { Logo } from "./ui";

// The plain pages behind the App Store listing: privacy policy and support.
export function LegalPage({ title, updated, lead, children }: { title: string; updated?: string; lead: string; children: ReactNode }) {
  return (
    <div className="flex min-h-full flex-1 flex-col">
      <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col gap-8 px-4 pt-6 pb-16 sm:px-6">
        <Logo />
        <header className="flex flex-col gap-3">
          <h1 className="font-display text-[clamp(26px,5vw,36px)] leading-tight font-bold">{title}</h1>
          {updated && <p className="font-mono text-xs tracking-wide text-faint uppercase">Last updated {updated}</p>}
          <p className="text-[17px] leading-relaxed text-soft">{lead}</p>
        </header>
        {children}
      </main>
      <footer className="border-t border-[#1c2232]">
        <div className="mx-auto flex max-w-2xl flex-wrap gap-x-5 gap-y-2 px-4 py-6 text-[13px] text-faint sm:px-6">
          <span>© 2026 Apticks</span>
          <Link href="/privacy" className="underline hover:text-text">Privacy policy</Link>
          <Link href="/support" className="underline hover:text-text">Help &amp; contact</Link>
          <a href={`mailto:${CONTACT_EMAIL}`} className="underline hover:text-text">{CONTACT_EMAIL}</a>
        </div>
      </footer>
    </div>
  );
}

export function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="flex flex-col gap-3">
      <h2 className="font-display text-lg font-bold">{title}</h2>
      {children}
    </section>
  );
}

export const P = ({ children }: { children: ReactNode }) => <p className="text-[15px] leading-relaxed text-soft">{children}</p>;

export function List({ children }: { children: ReactNode }) {
  return <ul className="flex list-disc flex-col gap-2 pl-5 text-[15px] leading-relaxed text-soft marker:text-lime">{children}</ul>;
}

export function Email({ subject }: { subject?: string }) {
  const href = `mailto:${CONTACT_EMAIL}${subject ? `?subject=${encodeURIComponent(subject)}` : ""}`;
  return (
    <a href={href} className="font-semibold text-lime underline hover:text-lime-hover">
      {CONTACT_EMAIL}
    </a>
  );
}
