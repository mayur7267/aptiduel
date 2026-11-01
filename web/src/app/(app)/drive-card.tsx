"use client";

import Link from "next/link";
import { useEffect, useState, type FormEvent } from "react";
import { api, type Drive } from "@/lib/api";
import { COMPANIES } from "@/lib/companies";
import { Calendar, ChevronRight, Target } from "@/components/icons";
import { Card, ErrorNote } from "@/components/ui";

type Set = Extract<Drive, { company: string }>;

const field = "h-11 w-full rounded-xl border border-line bg-surface px-3 text-[15px] text-text";
const primary = "h-11 rounded-xl bg-lime px-4 text-sm font-bold text-ink hover:bg-lime-hover disabled:opacity-70";
const choice =
  "h-11 flex-1 rounded-xl border border-line bg-raised px-3 text-sm font-semibold text-text hover:border-lime/60 disabled:opacity-60";

// Today in the browser, as YYYY-MM-DD.
function isoDay(offsetDays = 0) {
  const d = new Date(Date.now() + offsetDays * 86_400_000);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function prettyDate(iso: string) {
  return new Date(`${iso}T00:00:00`).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" });
}

// The placement test you're preparing for: a countdown, your practice on
// that company's topics, and afterwards, how it went. Those answers (with
// your rating) will tell everyone what a rating means for clearing a test.
export function DriveCard() {
  const [drive, setDrive] = useState<Drive | null>(null);
  const [editing, setEditing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    api.myDrive().then(
      (d) => active && setDrive(d),
      (e: Error) => active && setError(e.message),
    );
    return () => {
      active = false;
    };
  }, []);

  if (!drive) return error ? <ErrorNote message={error} /> : null;

  const saved = (d: Drive) => {
    setDrive(d);
    setEditing(false);
  };

  return (
    <Card
      data-tour="drive"
      className="relative overflow-hidden bg-[radial-gradient(420px_180px_at_100%_0%,rgba(165,148,255,0.14),transparent)] p-[22px]"
    >
      {drive.company === null || editing ? (
        <DriveForm current={drive.company === null ? null : drive} onSaved={saved} onCancel={editing ? () => setEditing(false) : null} />
      ) : drive.answered ? (
        <Thanks drive={drive} onNext={() => setEditing(true)} />
      ) : drive.days_left < 0 ? (
        <HowDidItGo drive={drive} onSaved={saved} />
      ) : (
        <Countdown drive={drive} onEdit={() => setEditing(true)} onReport={saved} />
      )}
    </Card>
  );
}

function DriveForm({ current, onSaved, onCancel }: { current: Set | null; onSaved: (d: Drive) => void; onCancel: (() => void) | null }) {
  const known = COMPANIES.some((c) => c.name === current?.company);
  const [company, setCompany] = useState(current ? (known ? current.company : "Other") : COMPANIES[0].name);
  const [other, setOther] = useState(current && !known ? current.company : "");
  // A past test's date is no use for the next one.
  const [date, setDate] = useState(current && current.days_left >= 0 ? current.drive_on : isoDay(14));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      onSaved(await api.setDrive(company === "Other" ? other.trim() : company, date));
    } catch (err) {
      setError((err as Error).message);
      setBusy(false);
    }
  }

  async function clear() {
    setBusy(true);
    try {
      onSaved(await api.setDrive(null, null));
    } catch (err) {
      setError((err as Error).message);
      setBusy(false);
    }
  }

  return (
    <form onSubmit={save} className="flex flex-col gap-3">
      <div className="flex items-center gap-2.5">
        <span className="flex size-9 items-center justify-center rounded-xl bg-violet-tint text-violet">
          <Calendar size={18} />
        </span>
        <div className="flex flex-col">
          <h2 className="text-[17px] font-bold">{current ? "Change your test" : "When's your placement test?"}</h2>
          <p className="text-sm text-muted">We&apos;ll count down to it and show what to practise.</p>
        </div>
      </div>
      <div className="grid gap-2.5 sm:grid-cols-[1fr_1fr_auto]">
        <label className="flex flex-col gap-1 text-xs font-semibold text-muted">
          Company
          <select value={company} onChange={(e) => setCompany(e.target.value)} className={field}>
            {COMPANIES.map((c) => (
              <option key={c.slug} value={c.name}>
                {c.name}
              </option>
            ))}
            <option value="Other">Another company</option>
          </select>
        </label>
        <label className="flex flex-col gap-1 text-xs font-semibold text-muted">
          Test date
          <input type="date" required value={date} min={isoDay(-30)} max={isoDay(365)} onChange={(e) => setDate(e.target.value)} className={field} />
        </label>
        <button type="submit" disabled={busy || (company === "Other" && other.trim().length < 2)} className={`${primary} self-end`}>
          {busy ? "Saving…" : current ? "Save" : "Start countdown"}
        </button>
      </div>
      {company === "Other" && (
        <input
          aria-label="Company name"
          placeholder="Company name"
          maxLength={40}
          value={other}
          onChange={(e) => setOther(e.target.value)}
          className={field}
        />
      )}
      {error && <ErrorNote message={error} />}
      {(onCancel || current) && (
        <div className="flex gap-4 text-sm">
          {onCancel && (
            <button type="button" onClick={onCancel} className="text-muted underline">
              Cancel
            </button>
          )}
          {current && (
            <button type="button" onClick={clear} disabled={busy} className="text-muted underline">
              I don&apos;t have a test coming up
            </button>
          )}
        </div>
      )}
    </form>
  );
}

function Countdown({ drive, onEdit, onReport }: { drive: Set; onEdit: () => void; onReport: (d: Drive) => void }) {
  const company = COMPANIES.find((c) => c.name === drive.company);
  const today = drive.days_left === 0;
  const [reporting, setReporting] = useState(false);
  if (reporting) return <HowDidItGo drive={drive} onSaved={onReport} />;

  return (
    <div className="flex flex-col gap-4 sm:flex-row sm:items-center">
      <div className="flex shrink-0 items-baseline gap-2 sm:flex-col sm:items-center sm:gap-0 sm:px-3">
        <span className="font-display text-[44px] leading-none font-bold text-violet">{today ? "🍀" : drive.days_left}</span>
        <span className="text-sm font-semibold text-muted">{today ? "today" : drive.days_left === 1 ? "day to go" : "days to go"}</span>
      </div>
      <div className="flex min-w-0 flex-1 flex-col gap-1.5">
        <h2 className="text-[17px] font-bold">
          {today ? `${drive.company} is today. All the best!` : `${drive.company} on ${prettyDate(drive.drive_on)}`}
        </h2>
        <p className="text-sm text-muted">
          {drive.practised
            ? `Last 30 days: ${drive.practised} ${drive.practised === 1 ? "question" : "questions"} on ${drive.company} topics, ${drive.accuracy}% right.`
            : `No practice on ${drive.company} topics yet. A company duel takes about 3 minutes.`}
        </p>
        {drive.weak_topics.length > 0 && (
          <p className="flex flex-wrap items-center gap-1.5 text-sm">
            <Target size={15} className="text-orange" />
            <span className="text-muted">Work on</span>
            {drive.weak_topics.map((t) => (
              <span key={t} className="rounded-lg bg-orange-tint px-2 py-0.5 text-xs font-semibold text-orange">
                {t}
              </span>
            ))}
          </p>
        )}
        <div className="mt-1 flex flex-wrap items-center gap-x-4 gap-y-2">
          <Link
            href={company ? `/play/${company.slug}` : "/play"}
            className="flex h-10 items-center gap-1.5 rounded-xl bg-lime px-4 text-sm font-bold text-ink hover:bg-lime-hover hover:text-ink"
          >
            {today ? "Warm up" : `Practise ${company ? company.name : "now"}`}
            <ChevronRight size={16} />
          </Link>
          {today ? (
            <button onClick={() => setReporting(true)} className="text-sm font-semibold text-lime hover:text-lime-hover">
              Done already? Tell us how it went
            </button>
          ) : (
            <button onClick={onEdit} className="text-sm text-muted underline">
              Change
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

function HowDidItGo({ drive, onSaved }: { drive: Set; onSaved: (d: Drive) => void }) {
  const [cleared, setCleared] = useState<"yes" | "no" | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function send(answer: "yes" | "no" | "skipped", difficulty: "easier" | "same" | "harder" | null) {
    setBusy(true);
    setError(null);
    try {
      onSaved(await api.submitDriveResult(answer, difficulty));
    } catch (e) {
      setError((e as Error).message);
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-col gap-1">
        <h2 className="text-[17px] font-bold">How did {drive.company} go?</h2>
        <p className="text-sm text-muted">
          Two taps. Your answer stays private, and it helps us show everyone what a rating means for clearing each test.
        </p>
      </div>
      {cleared === null ? (
        <>
          <span className="text-sm font-semibold">Did you clear the online test?</span>
          <div className="flex flex-wrap gap-2">
            <button disabled={busy} onClick={() => setCleared("yes")} className={choice}>Cleared it 🎉</button>
            <button disabled={busy} onClick={() => setCleared("no")} className={choice}>Didn&apos;t clear</button>
            <button disabled={busy} onClick={() => send("skipped", null)} className={choice}>Didn&apos;t take it</button>
          </div>
        </>
      ) : (
        <>
          <span className="text-sm font-semibold">Compared with Apticks, the test was…</span>
          <div className="flex flex-wrap gap-2">
            {(["easier", "same", "harder"] as const).map((d) => (
              <button key={d} disabled={busy} onClick={() => send(cleared, d)} className={choice}>
                {d === "same" ? "About the same" : d === "easier" ? "Easier" : "Harder"}
              </button>
            ))}
          </div>
          <button onClick={() => setCleared(null)} className="self-start text-sm text-muted underline">Back</button>
        </>
      )}
      {error && <ErrorNote message={error} />}
    </div>
  );
}

function Thanks({ drive, onNext }: { drive: Set; onNext: () => void }) {
  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
      <span className="text-[40px] leading-none">{drive.cleared === "yes" ? "🎉" : drive.cleared === "no" ? "💪" : "🙏"}</span>
      <div className="flex flex-1 flex-col gap-1">
        <h2 className="text-[17px] font-bold">
          {drive.cleared === "yes"
            ? `Congrats on clearing ${drive.company}!`
            : drive.cleared === "no"
              ? `${drive.company} wasn't your day. The next one will be.`
              : "Thanks for telling us."}
        </h2>
        <p className="text-sm text-muted">Got another test coming? Set it and we&apos;ll count down to it.</p>
      </div>
      <button onClick={onNext} className={`${primary} self-start sm:self-center`}>Set your next test</button>
    </div>
  );
}
