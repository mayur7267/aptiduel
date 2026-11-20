"use client";

import type { Subjects } from "@/lib/api";
import { tierFor } from "@/lib/format";
import type { Subject } from "@/lib/subjects";

// A player's rating in each subject, side by side, in the subjects' colours
// (Home's tabs: Aptitude lime, Coding violet, English orange). On your own
// profile a tile picks which rating the chart below shows.
const LOOK: Record<Subject, { label: string; glyph: string; on: string; accent: string }> = {
  aptitude: { label: "Aptitude", glyph: "Σ", on: "border-[#9fc41f] bg-lime text-ink", accent: "text-lime" },
  coding: { label: "Coding", glyph: "</>", on: "border-[#8676e6] bg-violet text-ink", accent: "text-violet" },
  english: { label: "English", glyph: "Aa", on: "border-[#d4683a] bg-orange text-ink", accent: "text-orange" },
};
const ORDER: Subject[] = ["aptitude", "coding", "english"];

export function SubjectRatings({
  subjects,
  selected,
  onSelect,
  mine = false,
}: {
  subjects: Subjects;
  selected?: Subject;
  onSelect?: (s: Subject) => void;
  mine?: boolean;
}) {
  // The tiles size to the row, not the screen: on the profile page's
  // narrow column (about 80px a tile) the numbers and padding shrink.
  return (
    <div role={onSelect ? "radiogroup" : undefined} aria-label="Rating in each subject" className="@container grid grid-cols-3 gap-2">
      {ORDER.map((s) => {
        const r = subjects[s];
        const played = r !== undefined && r.games > 0;
        const on = selected === s;
        const look = LOOK[s];
        const cls = `flex min-w-0 flex-col gap-1 overflow-hidden rounded-xl border-2 p-2 text-left transition @min-[300px]:p-2.5 ${
          on ? look.on : "border-line bg-ink/50 text-text"
        } ${onSelect && !on ? "hover:border-line-strong" : ""}`;
        const body = (
          <>
            <span
              className={`flex items-center gap-1 font-mono text-[10px] font-bold tracking-wide whitespace-nowrap uppercase @min-[300px]:tracking-wider ${on ? "" : look.accent}`}
            >
              <span aria-hidden="true" className="normal-case">{look.glyph}</span>
              {look.label}
            </span>
            <span className="font-display text-base leading-none font-bold @min-[300px]:text-lg @sm:text-xl">
              {played ? r.rating.toLocaleString("en-IN") : "—"}
            </span>
            {/* Tier and games on their own lines, so neither runs out of the tile. */}
            <span className={`text-[11px] leading-snug font-semibold ${on ? "opacity-80" : "text-muted"}`}>
              {played ? (
                <>
                  <span className="block truncate">{tierFor(r.rating).name}</span>
                  <span className="block truncate">{`${r.games} ${r.games === 1 ? "game" : "games"}`}</span>
                </>
              ) : mine ? (
                "Play your first"
              ) : (
                "Not played yet"
              )}
            </span>
          </>
        );
        return onSelect ? (
          <button key={s} role="radio" aria-checked={on} onClick={() => onSelect(s)} className={cls}>
            {body}
          </button>
        ) : (
          <div key={s} className={cls}>
            {body}
          </div>
        );
      })}
    </div>
  );
}
