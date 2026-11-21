"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { api, type Me } from "@/lib/api";
import { CollegeSearch, type PickedCollege } from "@/components/college-search";
import { ErrorNote, Spinner } from "@/components/ui";

const YEARS = [2024, 2025, 2026, 2027, 2028, 2029, 2030, 2031];
const field = "h-12 w-full rounded-xl border border-line bg-surface px-3.5 text-[15px] text-text";

// In a dialog, onSaved is called instead of leaving the page.
export function ProfileForm({ onSaved }: { onSaved?: () => void } = {}) {
  const router = useRouter();
  const [me, setMe] = useState<Me | null>(null);
  const [name, setName] = useState("");
  const [college, setCollege] = useState<PickedCollege | null>(null);
  const [gradYear, setGradYear] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    api
      .getMe()
      .then((m) => {
        if (!active) return;
        setMe(m);
        setName(/^Player \d{4}$/.test(m.name) ? "" : m.name);
        setCollege(m.college_id ? { id: m.college_id, name: m.college ?? "Your college" } : null);
        setGradYear(m.grad_year ? String(m.grad_year) : "");
      })
      .catch((e: Error) => active && setError(e.message));
    return () => {
      active = false;
    };
  }, []);

  async function save(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      await api.updateProfile(name, college?.id ?? null, gradYear ? Number(gradYear) : null);
      if (onSaved) {
        setSaving(false);
        onSaved();
      } else if (window.history.length > 1) router.back();
      else router.push("/");
    } catch (err) {
      setError((err as Error).message);
      setSaving(false);
    }
  }

  if (!me) return error ? <div className="mt-6"><ErrorNote message={error} /></div> : <Spinner />;

  return (
    <form onSubmit={save} className="mt-6 flex flex-col gap-5">
      <div className="flex flex-col gap-2">
        <label htmlFor="name" className="text-sm font-semibold">Name</label>
        <input
          id="name"
          required
          minLength={2}
          maxLength={24}
          autoComplete="nickname"
          placeholder="What friends call you"
          value={name}
          onChange={(e) => setName(e.target.value)}
          className={field}
        />
        <span className="text-xs text-muted">Shown on challenges and leaderboards.</span>
      </div>

      <div className="flex flex-col gap-2">
        <label htmlFor="college" className="text-sm font-semibold">College</label>
        <CollegeSearch id="college" value={college} onChange={setCollege} />
        <span className="text-xs text-muted">Colleges and universities in 224 countries.</span>
      </div>

      <div className="flex flex-col gap-2">
        <label htmlFor="year" className="text-sm font-semibold">Graduation year</label>
        <select id="year" value={gradYear} onChange={(e) => setGradYear(e.target.value)} className={field}>
          <option value="">Choose a year</option>
          {YEARS.map((y) => (
            <option key={y} value={y}>
              {y}
            </option>
          ))}
        </select>
      </div>

      {error && <ErrorNote message={error} />}

      <button
        type="submit"
        disabled={saving}
        className="h-14 rounded-2xl bg-lime text-base font-bold text-ink hover:bg-lime-hover disabled:opacity-70"
      >
        {saving ? "Saving…" : "Save"}
      </button>
    </form>
  );
}
