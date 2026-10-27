import { ImageResponse } from "next/og";
import { getChallenge } from "@/lib/challenge";
import { clock } from "@/lib/format";

export const alt = "An Apticks challenge";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

// The card WhatsApp shows under a shared challenge link.
export default async function Image({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  const ch = await getChallenge(code).catch(() => null);
  const name = ch?.challenger.name ?? "A friend";

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

        <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
          <div style={{ fontSize: 30, fontWeight: 700, color: "#c8f135", letterSpacing: 2 }}>
            {"YOU'VE BEEN CHALLENGED"}
          </div>
          <div style={{ fontSize: 70, fontWeight: 700, lineHeight: 1.08 }}>{`${name} challenged you to an aptitude duel`}</div>
        </div>

        <div style={{ display: "flex", gap: 24, alignItems: "center" }}>
          {ch?.challenger_finished && (
            <div
              style={{
                display: "flex",
                gap: 14,
                padding: "18px 28px",
                borderRadius: 20,
                background: "#151a26",
                border: "2px solid #272e40",
                fontSize: 34,
              }}
            >
              <span>Score to beat</span>
              <span style={{ color: "#ff8a4c", fontWeight: 700 }}>{`${ch.correct}/5 in ${clock(ch.total_ms)}`}</span>
            </div>
          )}
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
        </div>
      </div>
    ),
    size,
  );
}
