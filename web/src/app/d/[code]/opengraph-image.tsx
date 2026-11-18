import { ImageResponse } from "next/og";
import { getDailyShare } from "@/lib/daily-share";
import { clock } from "@/lib/format";

export const alt = "A friend's Apticks Daily result";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

// The card WhatsApp shows under a shared Daily link: who played, how they
// did per question (never the questions), and the ask.
export default async function Image({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  const r = await getDailyShare(code).catch(() => null);
  const name = r?.name ?? "A friend";
  const grid = r?.grid ?? [];

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          background: "#0b0e17",
          color: "#f2f4f8",
          padding: 72,
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
          {/* Same drawing as <Mark> in components/ui.tsx. */}
          <svg width="72" height="72" viewBox="0 0 64 64">
            <rect x="26" y="5" width="12" height="6" rx="2.5" fill="#f2f4f8" />
            <rect x="30" y="10" width="4" height="6" fill="#f2f4f8" />
            <circle cx="32" cy="37.5" r="21.5" fill="#c8f135" />
            <path d="M35.66 16.31L27.5 35.5L37 35.5L28.45 58.71A21.5 21.5 0 0 0 35.66 16.31Z" fill="#ff8a4c" />
            <path d="M35.66 16.31L27.5 35.5L37 35.5L28.45 58.71" fill="none" stroke="#0b0e17" strokeWidth="3.4" />
          </svg>
          <div style={{ display: "flex", fontSize: 40, fontWeight: 700 }}>
            <span>Ap</span>
            <span style={{ color: "#c8f135" }}>ticks</span>
          </div>
        </div>

        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 40 }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 18, maxWidth: 640 }}>
            <div style={{ fontSize: 30, fontWeight: 700, color: "#a594ff", letterSpacing: 2 }}>
              {r?.today === false ? "DAILY CHALLENGE" : "TODAY'S DAILY CHALLENGE"}
            </div>
            <div style={{ fontSize: 66, fontWeight: 700, lineHeight: 1.08 }}>
              {r ? `${name} got ${r.correct}/5` : `${name} played the Daily`}
            </div>
            {r && <div style={{ fontSize: 34, color: "#a6aec0" }}>{`in ${clock(r.total_ms)} · ${r.score} points`}</div>}
          </div>
          {grid.length > 0 && (
            <div style={{ display: "flex", gap: 12 }}>
              {grid.map((ok, i) => (
                <div
                  key={i}
                  style={{
                    width: 72,
                    height: 72,
                    borderRadius: 16,
                    background: ok ? "#c8f135" : "#ff6b7a",
                  }}
                />
              ))}
            </div>
          )}
        </div>

        <div style={{ display: "flex", gap: 24, alignItems: "center" }}>
          <div
            style={{
              display: "flex",
              padding: "18px 28px",
              borderRadius: 20,
              background: "#c8f135",
              color: "#0b0e17",
              fontSize: 34,
              fontWeight: 700,
            }}
          >
            Can you beat it?
          </div>
          <div style={{ fontSize: 30, color: "#a6aec0" }}>Same 5 questions for everyone · 3 minutes</div>
        </div>
      </div>
    ),
    size,
  );
}
