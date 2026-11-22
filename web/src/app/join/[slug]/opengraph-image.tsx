import { ImageResponse } from "next/og";
import { campusId, getCollegeCard } from "@/lib/campus";

export const alt = "Join your college on Apticks";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

// The card WhatsApp shows under a campus link: the college, how many
// play for it, and the ask.
export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const id = campusId(slug);
  const c = id === null ? null : await getCollegeCard(id).catch(() => null);
  const name = c?.name ?? "your college";
  const nameSize = name.length > 44 ? 52 : name.length > 28 ? 62 : 74;
  const players = c?.players ?? 0;

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
          <div style={{ fontSize: 30, fontWeight: 700, color: "#a594ff", letterSpacing: 2 }}>YOUR COLLEGE&apos;S LEADERBOARD</div>
          <div style={{ fontSize: nameSize, fontWeight: 700, lineHeight: 1.08, maxWidth: 1040 }}>{`Join ${name}`}</div>
          <div style={{ fontSize: 32, color: "#a6aec0" }}>
            {players > 0
              ? `${players} ${players === 1 ? "player" : "players"} · quick 1v1 aptitude, coding and English duels`
              : "Be #1 · quick 1v1 aptitude, coding and English duels"}
          </div>
        </div>

        <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
          <div
            style={{
              display: "flex",
              background: "#c8f135",
              color: "#0b0e17",
              fontSize: 30,
              fontWeight: 700,
              padding: "16px 30px",
              borderRadius: 18,
            }}
          >
            Join and play
          </div>
          <div style={{ fontSize: 26, color: "#a6aec0" }}>Free · no sign-up</div>
        </div>
      </div>
    ),
    size,
  );
}
