"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import { Bars, Calendar, Home, User } from "./icons";
import { Logo } from "./ui";

const NAV = [
  { href: "/", label: "Home", short: "Home", icon: Home },
  { href: "/daily", label: "Daily challenge", short: "Daily", icon: Calendar },
  { href: "/leaderboard", label: "Leaderboard", short: "Ranks", icon: Bars },
  { href: "/profile", label: "Profile", short: "Profile", icon: User },
];

// Sidebar on laptops, bottom tab bar on phones.
export function AppShell({ children }: { children: ReactNode }) {
  const path = usePathname();
  const isActive = (href: string) => (href === "/" ? path === "/" : path.startsWith(href));

  return (
    <div className="flex min-h-full flex-1">
      <aside className="sticky top-0 hidden h-dvh w-[240px] shrink-0 flex-col gap-7 border-r border-[#1c2232] bg-bar px-4 py-6 lg:flex">
        <div className="px-2">
          <Logo />
        </div>
        <nav aria-label="Main" className="flex flex-col gap-1">
          {NAV.map(({ href, label, icon: Icon }) => {
            const active = isActive(href);
            return (
              <Link
                key={href}
                data-tour={href === "/profile" ? "profile" : undefined}
                href={href}
                aria-current={active ? "page" : undefined}
                className={`flex h-11 items-center gap-3 rounded-xl px-3 text-[15px] font-semibold transition ${
                  active ? "sticker border border-line bg-surface text-lime [--pop:#1d2333]" : "border border-transparent text-muted hover:bg-surface/60 hover:text-text"
                }`}
              >
                <Icon size={20} />
                {label}
              </Link>
            );
          })}
        </nav>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col pb-24 lg:pb-0">{children}</div>

      <nav
        aria-label="Main"
        className="fixed inset-x-0 bottom-0 z-20 grid grid-cols-4 border-t border-line bg-bar/95 px-2 pt-2 pb-[max(env(safe-area-inset-bottom),12px)] backdrop-blur lg:hidden"
      >
        {NAV.map(({ href, short, icon: Icon }) => {
          const active = isActive(href);
          return (
            <Link
              key={href}
              data-tour={href === "/profile" ? "profile" : undefined}
              href={href}
              aria-current={active ? "page" : undefined}
              className={`flex min-h-12 flex-col items-center justify-center gap-1 text-[11px] font-semibold ${
                active ? "text-lime" : "text-faint"
              }`}
            >
              <Icon size={22} />
              {short}
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
