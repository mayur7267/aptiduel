"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { api, type Board, type BoardRow } from "@/lib/api";
import { batch, signed } from "@/lib/format";
import { useCompanionPage } from "@/lib/companion";
import { Avatar, ErrorNote, Logo, Spinner } from "@/components/ui";

type Scope = "college" | "india";

export function LeaderboardClient() {
  const [scope, setScope] = useState<Scope>("college");
  const [boards, setBoards] = useState<Partial<Record<Scope, Board>>>({});
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    api
      .leaderboard(scope, 50)
      .then((b) => {
        if (!active) return;
        setBoards((all) => ({ ...all, [scope]: b }));
        setError(null);
      })
      .catch((e: Error) => active && setError(e.message));
    return () => {
      active = false;
    };
  }, [scope]);

  const board = boards[scope];
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
            {s === "college" ? "My college" : "All India"}
          </button>
        ))}
      </div>

      {error && <ErrorNote message={error} />}
      {!board && !error && <Spinner label="Loading rankings" />}
      {board && <BoardView board={board} />}
    </main>
  );
}

function BoardView({ board }: { board: Board }) {
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
          <span className="text-[17px] font-bold">{board.scope === "college" ? board.college : "All India"}</span>
          <span className="text-xs text-muted">
            {board.players.toLocaleString("en-IN")} {board.players === 1 ? "player" : "players"} ranked by rating
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

      {board.rows.length === 0 ? (
        <p className="rounded-[20px] border border-dashed border-line p-6 text-sm text-muted">
          Nobody is ranked here yet. Play a Quick Match to take the top spot.
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
          You&apos;re not ranked yet. <Link href="/">Play a duel</Link> to get on the board.
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
          <span className="max-w-full truncate text-sm font-semibold">{r.is_me ? "You" : r.name}</span>
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
          {row.name}
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
