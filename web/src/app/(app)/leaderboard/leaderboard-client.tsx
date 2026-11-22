"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { api, type Board, type BoardRow, type ShareChannel } from "@/lib/api";
import { campusPath } from "@/lib/campus";
import { batch, signed, siteUrl } from "@/lib/format";
import { Copy, Message } from "@/components/icons";
import { useCompanionPage } from "@/lib/companion";
import type { Subject } from "@/lib/subjects";
import { Avatar, ErrorNote, Logo, Spinner } from "@/components/ui";

type Scope = "college" | "india";
type Key = `${Subject}:${Scope}`;

// A board per subject, in the subjects' colours (Home's tabs).
const SUBJECTS: { id: Subject; label: string; glyph: string; on: string; off: string }[] = [
  { id: "aptitude", label: "Aptitude", glyph: "Σ", on: "border-[#9fc41f] bg-lime text-ink", off: "text-lime" },
  { id: "coding", label: "Coding", glyph: "</>", on: "border-[#8676e6] bg-violet text-ink", off: "text-violet" },
  { id: "english", label: "English", glyph: "Aa", on: "border-[#d4683a] bg-orange text-ink", off: "text-orange" },
];
const PLAY_HREF: Record<Subject, string> = { aptitude: "/play", coding: "/play/coding", english: "/play/english" };

export function LeaderboardClient() {
  const [subject, setSubject] = useState<Subject>("aptitude");
  const [scope, setScope] = useState<Scope>("college");
  const [boards, setBoards] = useState<Partial<Record<Key, Board>>>({});
  const [error, setError] = useState<string | null>(null);
  // Your college's id, for its campus link.
  const [collegeId, setCollegeId] = useState<number | null>(null);
  const key: Key = `${subject}:${scope}`;

  useEffect(() => {
    api.getMe().then((m) => setCollegeId(m.college_id), () => {});
  }, []);

  useEffect(() => {
    let active = true;
    api
      .leaderboard(scope, 50, subject)
      .then((b) => {
        if (!active) return;
        setBoards((all) => ({ ...all, [`${subject}:${scope}`]: b }));
        setError(null);
      })
      .catch((e: Error) => active && setError(e.message));
    return () => {
      active = false;
    };
  }, [scope, subject]);

  const board = boards[key];
  const empty = board !== undefined && board.rows.length === 0 && !(board.scope === "college" && !board.college);
  useCompanionPage(
    empty ? { mood: "think", say: "Nobody's ranked here yet. One Quick Match puts you on top!" } : { mood: "point" },
  );

  return (
    <main className="mx-auto flex w-full max-w-[880px] flex-col gap-5 px-4 pt-5 pb-12 sm:px-6 lg:px-10 lg:pt-8">
      <div className="lg:hidden">
        <Logo />
      </div>
      <div className="flex items-center justify-between gap-3">
        <h1 className="font-display text-[clamp(22px,2.4vw,30px)] font-bold">Leaderboard</h1>
        <span className="rounded-full border border-line bg-surface px-3 py-1.5 text-xs font-semibold text-muted">
          By rating
        </span>
      </div>

      <div role="radiogroup" aria-label="Subject" className="grid grid-cols-3 gap-2">
        {SUBJECTS.map((s) => {
          const on = s.id === subject;
          return (
            <button
              key={s.id}
              role="radio"
              aria-checked={on}
              onClick={() => {
                setSubject(s.id);
                setError(null);
              }}
              className={`flex h-11 items-center justify-center gap-1.5 rounded-xl border-2 text-[15px] font-bold transition ${
                on ? s.on : `border-line bg-surface hover:bg-raised ${s.off}`
              }`}
            >
              <span aria-hidden="true" className="font-mono text-sm">
                {s.glyph}
              </span>
              {s.label}
            </button>
          );
        })}
      </div>

      <div role="group" aria-label="Leaderboard" className="sticker grid grid-cols-2 rounded-2xl border-2 border-line bg-surface p-1">
        {(["college", "india"] as const).map((s) => (
          <button
            key={s}
            aria-pressed={scope === s}
            onClick={() => {
              setScope(s);
              setError(null);
            }}
            className={`h-11 rounded-xl text-[15px] font-bold transition ${
              scope === s ? "bg-text text-ink" : "text-muted hover:text-text"
            }`}
          >
            {s === "college" ? "My college" : "Everyone"}
          </button>
        ))}
      </div>

      {error && <ErrorNote message={error} />}
      {!board && !error && <Spinner label="Loading rankings" />}
      {board && <BoardView board={board} subject={subject} collegeId={collegeId} />}
    </main>
  );
}

function BoardView({ board, subject, collegeId }: { board: Board; subject: Subject; collegeId: number | null }) {
  const name = SUBJECTS.find((s) => s.id === subject)?.label ?? "Aptitude";
  if (board.scope === "college" && !board.college) {
    return (
      <div className="flex flex-col items-start gap-3 rounded-[20px] border border-line bg-surface p-5">
        <h2 className="text-lg font-bold">Pick your college first</h2>
        <p className="text-sm text-muted">Add your college to your profile to see how you rank against your batchmates.</p>
        <Link href="/profile" className="rounded-xl bg-lime px-4 py-2.5 text-sm font-bold text-ink hover:bg-lime-hover">
          Add your college
        </Link>
      </div>
    );
  }

  const top = board.rows.slice(0, 3);
  const rest = board.rows.length >= 3 ? board.rows.slice(3) : board.rows;
  const me = board.me;

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-col gap-0.5">
          <span className="text-[17px] font-bold">{board.scope === "college" ? board.college : "Everyone"}</span>
          <span className="text-xs text-muted">
            {board.players.toLocaleString("en-IN")} {board.players === 1 ? "player" : "players"} ranked by {name} rating
            · +/− is this week&apos;s change
          </span>
        </div>
        {me && (
          <span className="rounded-full bg-lime-tint px-3 py-1.5 text-xs font-bold text-lime">
            You&apos;re #{me.rank}
            {me.week_delta !== 0 && ` · ${signed(me.week_delta)} this week`}
          </span>
        )}
      </div>

      {board.scope === "college" && board.college && collegeId !== null && <InviteCard collegeId={collegeId} college={board.college} />}

      {board.rows.length === 0 ? (
        <p className="rounded-[20px] border border-dashed border-line p-6 text-sm text-muted">
          Nobody is ranked in {name} here yet. <Link href={PLAY_HREF[subject]}>Play a {name} Quick Match</Link> to take the top spot.
        </p>
      ) : (
        <>
          {top.length === 3 && <Podium rows={top} />}
          <ol className="flex flex-col gap-2">
            {rest.map((r) => (
              <Row key={`${r.rank}-${r.name}`} row={r} scope={board.scope} />
            ))}
          </ol>
        </>
      )}

      {me ? (
        // Pinned only when your row isn't already in the list above.
        !board.rows.some((r) => r.is_me) && (
          <ol aria-label="Your rank" className="sticky bottom-[92px] lg:bottom-5">
            <Row row={me} scope={board.scope} pinned />
          </ol>
        )
      ) : (
        <p className="text-sm text-muted">
          You&apos;re not ranked in {name} yet. <Link href={PLAY_HREF[subject]}>Play a {name} duel</Link> to get on the board.
        </p>
      )}
    </div>
  );
}

function Podium({ rows }: { rows: BoardRow[] }) {
  // Second, first, third, so the winner stands in the middle.
  const order = [rows[1], rows[0], rows[2]];
  const styles = [
    { block: "h-20 bg-raised text-soft [--pop:#151a26]", ring: "border-soft", size: 52 },
    { block: "h-28 bg-lime text-ink [--pop:#5f7710]", ring: "border-lime", size: 64 },
    { block: "h-16 bg-raised text-orange [--pop:#151a26]", ring: "border-orange", size: 52 },
  ];
  return (
    <ol className="grid grid-cols-3 items-end gap-3" aria-label="Top three">
      {order.map((r, i) => (
        <li key={r.rank + r.name} className="flex min-w-0 flex-col items-center gap-2">
          <span className={`rounded-full border-[3px] ${styles[i].ring}`}>
            <Avatar name={r.name} size={styles[i].size} />
          </span>
          <span className="max-w-full truncate text-sm font-semibold">
            {r.is_me ? (
              "You"
            ) : r.id ? (
              <Link href={`/u/${r.id}`} className="text-text hover:text-lime">
                {r.name}
              </Link>
            ) : (
              r.name
            )}
          </span>
          <span className="font-mono text-xs text-muted">{r.rating.toLocaleString("en-IN")}</span>
          <span
            className={`sticker flex w-full items-center justify-center rounded-t-2xl rounded-b-md font-display text-2xl font-bold ${styles[i].block}`}
          >
            {r.rank}
          </span>
        </li>
      ))}
    </ol>
  );
}

function Row({ row, scope, pinned = false }: { row: BoardRow; scope: Scope; pinned?: boolean }) {
  const meta = scope === "india" ? row.college : batch(row.grad_year);
  return (
    <li
      className={`flex items-center gap-3 rounded-2xl border px-3.5 py-2.5 ${
        row.is_me ? "border-[1.5px] border-lime bg-[#161d10]" : "border-line bg-surface"
      } ${pinned ? "shadow-[0_-8px_24px_rgba(11,14,23,0.9)]" : ""}`}
    >
      <span className={`w-7 font-mono text-sm font-bold ${row.is_me ? "text-lime" : "text-muted"}`}>{row.rank}</span>
      <Avatar name={row.name} size={36} />
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="truncate text-sm font-semibold">
          {row.id && !row.is_me ? (
            <Link href={`/u/${row.id}`} className="text-text hover:text-lime">
              {row.name}
            </Link>
          ) : (
            row.name
          )}
          {row.is_me && " (You)"}
        </span>
        {meta && <span className="truncate text-xs text-muted">{meta}</span>}
      </span>
      <span className="flex flex-col items-end">
        <span className="font-mono text-sm font-bold">{row.rating.toLocaleString("en-IN")}</span>
        {row.week_delta !== 0 && (
          <span className={`text-xs font-semibold ${row.week_delta > 0 ? "text-lime" : "text-red"}`}>
            {signed(row.week_delta)}
          </span>
        )}
      </span>
    </li>
  );
}

// The campus link (0029_campus_links): whoever opens it lands on this
// board, so one message in the class group fills it.
function InviteCard({ collegeId, college }: { collegeId: number; college: string }) {
  const url = siteUrl(campusPath(collegeId, college));
  const [copied, setCopied] = useState(false);
  const text = `Our college has its own leaderboard on Apticks 🏆 Quick 1v1 aptitude, coding and English duels. Join ${college} and let's see who's #1: ${url}`;
  const log = (channel: ShareChannel) => api.logShare("campus", channel, null).catch(() => {});

  async function copy() {
    log("copy");
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard can be blocked; WhatsApp still works.
    }
  }

  return (
    <div className="flex flex-col gap-3 rounded-[20px] border border-line bg-surface p-4 sm:flex-row sm:items-center">
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="font-bold">Get your class on this board</span>
        <span className="text-[13px] text-muted">Share {college}&apos;s link in your class group. Everyone who opens it lands here.</span>
      </div>
      <div className="flex gap-2">
        <a
          href={`https://wa.me/?text=${encodeURIComponent(text)}`}
          target="_blank"
          rel="noopener noreferrer"
          onClick={() => log("whatsapp")}
          className="flex h-11 flex-1 items-center justify-center gap-2 rounded-xl bg-lime px-4 text-sm font-bold whitespace-nowrap text-ink hover:bg-lime-hover hover:text-ink sm:flex-none"
        >
          <Message size={18} strokeWidth={2.2} />
          Invite on WhatsApp
        </a>
        <button
          onClick={copy}
          className="flex h-11 items-center gap-2 rounded-xl border border-line bg-raised px-3 text-sm font-semibold whitespace-nowrap hover:bg-line"
        >
          <Copy size={16} />
          {copied ? "Copied" : "Copy link"}
        </button>
      </div>
    </div>
  );
}
