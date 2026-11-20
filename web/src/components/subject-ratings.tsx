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
  return (
    <div role={onSelect ? "radiogroup" : undefined} aria-label="Rating in each subject" className="grid grid-cols-3 gap-2">
      {ORDER.map((s) => {
        const r = subjects[s];
        const played = r !== undefined && r.games > 0;
        const on = selected === s;
        const look = LOOK[s];
        const cls = `flex min-w-0 flex-col items-start gap-1 rounded-xl border-2 p-2.5 text-left transition ${
          on ? look.on : "border-line bg-ink/50 text-text"
        } ${onSelect && !on ? "hover:border-line-strong" : ""}`;
        const body = (
          <>
            <span className={`flex items-center gap-1 font-mono text-[10px] font-bold tracking-wider uppercase ${on ? "" : look.accent}`}>
              <span aria-hidden="true" className="normal-case">{look.glyph}</span>
              {look.label}
            </span>
            <span className="font-display text-xl leading-none font-bold">{played ? r.rating.toLocaleString("en-IN") : "—"}</span>
            <span className={`truncate text-[11px] font-semibold ${on ? "opacity-80" : "text-muted"}`}>
              {played ? `${tierFor(r.rating).name} · ${r.games} ${r.games === 1 ? "game" : "games"}` : mine ? "Play your first" : "Not played yet"}
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
