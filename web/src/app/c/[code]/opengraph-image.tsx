import { ImageResponse } from "next/og";
import { getChallenge } from "@/lib/challenge";
import { clock } from "@/lib/format";

export const alt = "An AptiDuel challenge";
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
        <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
          <div
            style={{
              width: 64,
              height: 64,
              borderRadius: 18,
              background: "#c8f135",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#0b0e17" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round">
              <path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z" />
            </svg>
          </div>
          <div style={{ fontSize: 38, fontWeight: 700 }}>AptiDuel</div>
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
