import { floorColor } from "@/lib/streak";

// One day of the Streak Tower: a chunky block in its floor's colour, with
// the day number and the weekday. Used by the celebration and the streak
// page. Width and height are in px; everything inside scales with them.
export function StreakBlock({ day, weekday, width, height, glow = false }: { day: number; weekday: string; width: number; height: number; glow?: boolean }) {
  const fill = floorColor(day);
  const fs = Math.round(height * 0.34);
  return (
    <div
      className="relative flex items-center justify-between overflow-hidden rounded-[14px] border-[3.5px] border-ink px-[8%] text-ink"
      style={{ width, height, background: fill, boxShadow: `0 ${Math.round(height * 0.12)}px 0 #0b0e17${glow ? ", 0 0 0 4px #ffffff" : ""}`, fontSize: fs }}
    >
      {/* Bricks: two seams, offset like a wall. */}
      <span aria-hidden="true" className="absolute inset-x-0 top-1/2 h-[3px] -translate-y-1/2 bg-ink/15" />
      <span aria-hidden="true" className="absolute top-0 bottom-1/2 left-[38%] w-[3px] bg-ink/15" />
      <span aria-hidden="true" className="absolute top-1/2 bottom-0 left-[68%] w-[3px] bg-ink/15" />
      <span className="relative font-display font-bold tracking-tight">DAY {day}</span>
      <span className="relative font-mono font-bold opacity-70" style={{ fontSize: fs * 0.8 }}>
        {weekday}
      </span>
    </div>
  );
}
