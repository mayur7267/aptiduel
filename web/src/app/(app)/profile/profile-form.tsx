"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { api, type Me } from "@/lib/api";
import { ErrorNote, Spinner } from "@/components/ui";

const YEARS = [2024, 2025, 2026, 2027, 2028, 2029, 2030, 2031];
const field = "h-12 w-full rounded-xl border border-line bg-surface px-3.5 text-[15px] text-text";

export function ProfileForm() {
  const router = useRouter();
  const [me, setMe] = useState<Me | null>(null);
  const [colleges, setColleges] = useState<{ id: number; name: string }[]>([]);
  const [name, setName] = useState("");
  const [collegeId, setCollegeId] = useState("");
  const [gradYear, setGradYear] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    Promise.all([api.getMe(), api.colleges()])
      .then(([m, list]) => {
        if (!active) return;
        setMe(m);
        setColleges(list);
        setName(/^Player \d{4}$/.test(m.name) ? "" : m.name);
        setCollegeId(m.college_id ? String(m.college_id) : "");
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
      await api.updateProfile(name, collegeId ? Number(collegeId) : null, gradYear ? Number(gradYear) : null);
      if (window.history.length > 1) router.back();
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
        <select id="college" value={collegeId} onChange={(e) => setCollegeId(e.target.value)} className={field}>
          <option value="">Choose your college</option>
          {colleges.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
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

      <p className="text-xs leading-relaxed text-muted">
        You&apos;re playing as a guest on this device. Your rating stays here as long as you use the same browser.
      </p>
    </form>
  );
}
