import type { Metadata } from "next";
import Link from "next/link";
import { notFound, permanentRedirect } from "next/navigation";
import { Suspense } from "react";
import { campusId, campusPath, getCollegeCard, type CollegeCard } from "@/lib/campus";
import { Check, Trophy } from "@/components/icons";
import { Avatar, Logo } from "@/components/ui";
import { Tiko } from "@/components/tiko";
import { JoinPanel } from "./join-panel";

// A campus link: one college's own page. A class shares it in their
// WhatsApp group, everyone lands on the same board, and one tap joins it
// and starts a duel.

const place = (c: CollegeCard) => [c.city, c.country && new Intl.DisplayNames(["en"], { type: "region" }).of(c.country)].filter(Boolean).join(", ");

export async function generateMetadata({ params }: PageProps<"/join/[slug]">): Promise<Metadata> {
  const { slug } = await params;
  const id = campusId(slug);
  const c = id === null ? null : await getCollegeCard(id).catch(() => null);
  if (!c) return { title: "College not found" };
  const title = `Join ${c.name} on Apticks`;
  const description = `${c.name} has its own Apticks leaderboard. Quick 1v1 aptitude, coding and English duels: climb your college's board. Free, no sign-up.`;
  return { title, description, openGraph: { title, description }, robots: { index: false } };
}

export default function JoinPage({ params }: PageProps<"/join/[slug]">) {
  return (
    <div className="flex min-h-full flex-1 flex-col">
      <header className="border-b border-[#1c2232]">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-4 sm:px-6">
          <Logo />
          <Link href="/" className="rounded-xl border border-line bg-surface px-4 py-2.5 text-sm font-semibold text-text hover:bg-raised">
            Explore Apticks
          </Link>
        </div>
      </header>

      <main className="flex-1">
        <Suspense
          fallback={
            <section className="mx-auto max-w-6xl px-4 py-12 sm:px-6 sm:py-16">
              <div aria-hidden="true" className="flex animate-pulse flex-col gap-5">
                <div className="h-7 w-48 rounded-full bg-surface" />
                <div className="h-28 w-full max-w-[520px] rounded-2xl bg-surface" />
                <div className="h-14 w-56 rounded-2xl bg-surface" />
              </div>
            </section>
          }
        >
          <Body params={params} />
        </Suspense>
      </main>

      <footer className="border-t border-[#1c2232]">
        <div className="mx-auto max-w-6xl px-4 py-6 text-[13px] text-faint sm:px-6">
          © 2026 Apticks · <Link href="/privacy" className="underline hover:text-text">Privacy</Link> ·{" "}
          <Link href="/support" className="underline hover:text-text">Help</Link>
        </div>
      </footer>
    </div>
  );
}

const STEPS = [
  ["01", "Tap join", "You're on your college's board straight away. No sign-up, no form."],
  ["02", "Play a 1v1 duel", "5 questions in Aptitude, Coding or English, against someone at your level."],
  ["03", "Climb the board", "Every win moves your rating up. See where you stand in your college."],
];

async function Body({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const id = campusId(slug);
  const c = id === null ? null : await getCollegeCard(id);
  if (!c) notFound();
  // One address per college, whatever name was typed after the id.
  const canonical = campusPath(c.id, c.name);
  if (`/join/${decodeURIComponent(slug)}` !== canonical) permanentRedirect(canonical);
  const where = place(c);

  return (
    <>
      <section className="mx-auto flex max-w-6xl flex-wrap items-center gap-10 px-4 py-10 sm:px-6 sm:py-16">
        <div className="flex min-w-0 flex-[1_1_480px] flex-col gap-5">
          <span className="flex items-center gap-2 self-start rounded-full bg-lime-tint px-3 py-1.5 text-[13px] font-bold text-lime">
            <Trophy size={14} strokeWidth={2.4} />
            Your college&apos;s leaderboard
          </span>
          <h1 className={`font-display leading-[1.08] font-bold tracking-tight ${c.name.length > 28 ? "text-[clamp(28px,3.6vw,44px)]" : "text-[clamp(30px,4.6vw,54px)]"}`}>
            Join {c.name} on Apticks
          </h1>
          <p className="max-w-[520px] text-lg leading-relaxed text-muted">
            {c.players > 0
              ? `${c.players.toLocaleString("en-IN")} ${c.players === 1 ? "student plays" : "students play"} for ${c.name}. Play quick 1v1 duels in Aptitude, Coding and English, and see who's #1.`
              : `Nobody from ${c.name} is on the board yet. Play one quick 1v1 duel and you're #1.`}
          </p>

          <JoinPanel id={c.id} name={c.name} />

          <div className="flex flex-wrap gap-x-5 gap-y-2 text-[13px] text-muted">
            {["Free", "No sign-up", "Works in any browser"].map((t) => (
              <span key={t} className="flex items-center gap-1.5">
                <Check size={14} strokeWidth={3} className="text-lime" />
                {t}
              </span>
            ))}
          </div>
        </div>

        <div className="flex min-w-0 flex-[1_1_360px] justify-center pt-10">
          <div className="relative w-full max-w-[420px]">
            <BoardCard c={c} where={where} />
            <Tiko mood="wave" size={84} className="absolute -top-[72px] -left-3 z-10" />
          </div>
        </div>
      </section>

      <section className="border-t border-[#1c2232] bg-[#0e121c]">
        <div className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-14 sm:px-6">
          <h2 className="font-display text-2xl font-bold sm:text-3xl">How it works</h2>
          <div className="grid gap-4 sm:grid-cols-3">
            {STEPS.map(([n, title, body]) => (
              <div key={n} className="flex flex-col gap-2.5 rounded-[20px] border border-line bg-surface p-5">
                <span className="font-display text-2xl font-bold text-lime">{n}</span>
                <span className="text-[17px] font-bold">{title}</span>
                <span className="text-[15px] leading-relaxed text-muted">{body}</span>
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}

// The college's top three, or an empty spot waiting for the first player.
function BoardCard({ c, where }: { c: CollegeCard; where: string }) {
  return (
    <div className="sticker flex w-full -rotate-1 flex-col gap-4 rounded-[28px] border-2 border-lime/40 bg-surface p-6 [--pop:#3d4d0a]">
      <div className="flex flex-col gap-0.5">
        <span className="font-bold">{c.name}</span>
        <span className="text-[13px] text-muted">
          {where ? `${where} · ` : ""}
          {c.players.toLocaleString("en-IN")} {c.players === 1 ? "player" : "players"}
        </span>
      </div>
      {c.top.length > 0 ? (
        <ol className="flex flex-col gap-2">
          {c.top.map((p, i) => (
            <li key={`${i}-${p.name}`} className="flex items-center gap-3 rounded-2xl border border-line bg-raised px-3 py-2.5">
              <span className={`w-5 text-center font-mono text-sm font-bold ${i === 0 ? "text-lime" : "text-muted"}`}>{i + 1}</span>
              <Avatar name={p.name} size={34} />
              <span className="min-w-0 flex-1 truncate font-semibold">{p.name}</span>
              <span className="font-mono text-sm text-soft">{p.rating.toLocaleString("en-IN")}</span>
            </li>
          ))}
          {c.players > 3 && <li className="px-3 text-[13px] text-muted">and {(c.players - 3).toLocaleString("en-IN")} more</li>}
        </ol>
      ) : (
        <div className="flex items-center gap-3 rounded-2xl border border-dashed border-line px-4 py-5">
          <span className="font-display text-3xl font-bold text-lime">#1</span>
          <span className="text-[15px] leading-snug text-muted">is free. The first duel from {c.name} takes it.</span>
        </div>
      )}
    </div>
  );
}
