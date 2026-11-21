"use client";

import { useEffect, useId, useMemo, useRef, useState, type KeyboardEvent } from "react";
import { api, type CollegeHit } from "@/lib/api";
import { Plus, Search } from "./icons";

export type PickedCollege = { id: number; name: string; city?: string | null; country?: string | null };

// The countries with colleges on the list (supabase/migrations/0027), for
// adding a college that's missing.
const COUNTRIES = (
  "AD AE AF AG AI AL AM AO AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BM BN BO BQ BR BS BT BW " +
  "BY BZ CA CD CF CG CH CI CL CM CN CO CR CU CV CW CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI " +
  "FJ FM FO FR GA GB GD GE GF GH GI GL GM GN GP GQ GR GT GU GW GY HK HN HR HT HU ID IE IL IN IQ IR " +
  "IS IT JM JO JP KE KG KH KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MG MK " +
  "ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NG NI NL NO NP NU NZ OM PA PE PF PG PH PK " +
  "PL PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ " +
  "TC TD TG TH TJ TL TM TN TO TR TT TW TZ UA UG US UY UZ VA VC VE VG VI VN VU WS XK YE YT ZA ZM ZW"
).split(" ");

const regions = new Intl.DisplayNames(["en"], { type: "region" });
export const countryName = (cc?: string | null) => {
  if (!cc) return "";
  try {
    return regions.of(cc) ?? cc;
  } catch {
    return cc;
  }
};
// "IN" -> 🇮🇳
export const flag = (cc?: string | null) =>
  cc && /^[A-Z]{2}$/.test(cc) ? String.fromCodePoint(...[...cc].map((c) => 0x1f1e6 + c.charCodeAt(0) - 65)) : "";
const place = (c: { city?: string | null; country?: string | null }) =>
  [c.city, countryName(c.country)].filter(Boolean).join(", ");

// The player's own country, from the browser's language ("en-GB" -> GB),
// as a hint for search and the default for adding a college.
function homeCountry() {
  if (typeof navigator === "undefined") return "IN";
  try {
    return new Intl.Locale(navigator.language).maximize().region ?? "IN";
  } catch {
    return "IN";
  }
}

const field = "h-12 w-full rounded-xl border border-line bg-surface px-3.5 text-[15px] text-text";

// Type to search about 34,000 colleges in 224 countries; pick one, or add
// yours if it's missing. It sits inside the profile form, so Enter picks
// or adds instead of submitting the form.
export function CollegeSearch({
  id,
  value,
  onChange,
}: {
  id: string;
  value: PickedCollege | null;
  onChange: (college: PickedCollege | null) => void;
}) {
  const listId = useId();
  const input = useRef<HTMLInputElement>(null);
  const seq = useRef(0);
  const [query, setQuery] = useState("");
  const [hits, setHits] = useState<{ q: string; list: CollegeHit[] } | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [active, setActive] = useState(0);
  const [country, setCountry] = useState(homeCountry);
  const [adding, setAdding] = useState(false);
  const [newName, setNewName] = useState("");
  const [newCity, setNewCity] = useState("");
  const [addError, setAddError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const q = query.trim();
  const searching = q.length >= 2;

  useEffect(() => {
    if (q.length < 2) return;
    const n = ++seq.current;
    const t = setTimeout(() => {
      setLoading(true);
      api
        .searchColleges(q, country)
        .then((list) => {
          if (n !== seq.current) return;
          setHits({ q, list });
          setActive(0);
          setError(null);
        })
        .catch((e: Error) => n === seq.current && setError(e.message))
        .finally(() => n === seq.current && setLoading(false));
    }, 200);
    return () => clearTimeout(t);
  }, [q, country]);

  const countries = useMemo(
    () => COUNTRIES.map((cc) => ({ cc, name: countryName(cc) })).sort((a, b) => a.name.localeCompare(b.name)),
    [],
  );

  const list = searching && hits ? hits.list : [];
  const open = searching && !adding && (hits !== null || loading || error !== null);

  function pick(c: PickedCollege) {
    onChange(c);
    setQuery("");
    setHits(null);
    setAdding(false);
  }

  function startAdding() {
    setNewName(q);
    setNewCity("");
    setAddError(null);
    setAdding(true);
  }

  async function add() {
    const name = newName.trim();
    if (name.length < 3) {
      setAddError("College names are at least 3 characters.");
      return;
    }
    setSaving(true);
    setAddError(null);
    try {
      const newId = await api.addCollege(name, newCity.trim() || null, country);
      pick({ id: newId, name, city: newCity.trim() || null, country });
    } catch (e) {
      setAddError((e as Error).message);
    } finally {
      setSaving(false);
    }
  }

  function onKey(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "ArrowDown" && list.length) {
      e.preventDefault();
      setActive((a) => Math.min(a + 1, list.length - 1));
    } else if (e.key === "ArrowUp" && list.length) {
      e.preventDefault();
      setActive((a) => Math.max(a - 1, 0));
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (list[active]) pick(list[active]);
    } else if (e.key === "Escape") {
      setQuery("");
    }
  }

  if (value) {
    return (
      <div className="flex items-center gap-3 rounded-xl border border-line bg-surface px-3.5 py-2.5">
        <span className="text-xl" aria-hidden="true">{flag(value.country) || "🎓"}</span>
        <span className="flex min-w-0 flex-1 flex-col">
          <span className="truncate text-[15px] font-semibold">{value.name}</span>
          {place(value) && <span className="truncate text-xs text-muted">{place(value)}</span>}
        </span>
        <button
          type="button"
          onClick={() => {
            onChange(null);
            requestAnimationFrame(() => document.getElementById(id)?.focus());
          }}
          className="text-sm font-bold text-lime"
        >
          Change
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="relative">
        <Search size={18} className="pointer-events-none absolute top-1/2 left-3.5 -translate-y-1/2 text-muted" />
        <input
          id={id}
          ref={input}
          type="search"
          role="combobox"
          aria-expanded={open}
          aria-controls={listId}
          aria-autocomplete="list"
          aria-activedescendant={open && list[active] ? `${listId}-${active}` : undefined}
          autoComplete="off"
          placeholder="Search your college, in any country"
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setAdding(false);
          }}
          onKeyDown={onKey}
          className={`${field} pl-10`}
        />
      </div>

      {open && (
        <ul id={listId} role="listbox" className="max-h-80 overflow-y-auto rounded-xl border border-line bg-surface py-1">
          {list.map((c, i) => (
            <li
              key={c.id}
              id={`${listId}-${i}`}
              role="option"
              aria-selected={i === active}
              onMouseDown={(e) => {
                e.preventDefault();
                pick(c);
              }}
              onMouseEnter={() => setActive(i)}
              className={`flex cursor-pointer items-center gap-3 px-3.5 py-2.5 ${i === active ? "bg-line" : ""}`}
            >
              <span className="text-lg" aria-hidden="true">{flag(c.country) || "🎓"}</span>
              <span className="flex min-w-0 flex-1 flex-col">
                <span className="truncate text-[15px] font-semibold">{c.name}</span>
                {place(c) && <span className="truncate text-xs text-muted">{place(c)}</span>}
              </span>
              {c.players > 0 && (
                <span className="shrink-0 rounded-full bg-lime-tint px-2 py-0.5 font-mono text-[11px] font-bold text-lime">
                  {c.players} {c.players === 1 ? "player" : "players"}
                </span>
              )}
            </li>
          ))}
          {loading && !hits && <li className="px-3.5 py-3 text-sm text-muted">Searching…</li>}
          {error && <li className="px-3.5 py-3 text-sm text-orange">{error}</li>}
          {hits && !list.length && !loading && (
            <li className="px-3.5 pt-3 pb-1 text-sm text-muted">No college matches “{q}” yet.</li>
          )}
          {hits && (
            <li>
              <button
                type="button"
                onMouseDown={(e) => e.preventDefault()}
                onClick={startAdding}
                className="flex w-full items-center gap-2 px-3.5 py-3 text-left text-sm font-bold text-lime"
              >
                <Plus size={16} strokeWidth={2.6} /> Can&apos;t find it? Add your college
              </button>
            </li>
          )}
        </ul>
      )}

      {adding && (
        <div className="flex flex-col gap-2 rounded-xl border border-line bg-surface p-3">
          <span className="text-sm font-semibold">Add your college</span>
          <input
            aria-label="College name"
            placeholder="College name"
            maxLength={120}
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                void add();
              }
            }}
            className={field}
          />
          <input
            aria-label="City"
            placeholder="City (optional)"
            maxLength={80}
            value={newCity}
            onChange={(e) => setNewCity(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                void add();
              }
            }}
            className={field}
          />
          <select aria-label="Country" value={country} onChange={(e) => setCountry(e.target.value)} className={field}>
            {countries.map((c) => (
              <option key={c.cc} value={c.cc}>
                {flag(c.cc)} {c.name}
              </option>
            ))}
          </select>
          {addError && <span className="text-sm text-orange">{addError}</span>}
          <div className="flex gap-2">
            <button
              type="button"
              disabled={saving}
              onClick={() => void add()}
              className="h-11 flex-1 rounded-xl bg-lime text-sm font-bold text-ink hover:bg-lime-hover disabled:opacity-70"
            >
              {saving ? "Adding…" : "Add college"}
            </button>
            <button type="button" onClick={() => setAdding(false)} className="h-11 rounded-xl px-4 text-sm font-semibold text-muted">
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
