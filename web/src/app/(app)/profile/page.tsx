import type { Metadata } from "next";
import Link from "next/link";
import { Tiko } from "@/components/tiko";
import { Logo } from "@/components/ui";
import { AccountPanel } from "./account-panel";
import { ProfileForm } from "./profile-form";

export const metadata: Metadata = { title: "Your profile", robots: { index: false } };

export default function ProfilePage() {
  return (
    <main className="mx-auto w-full max-w-xl px-4 pt-5 pb-12 sm:px-6 lg:pt-8">
      <div className="mb-5 lg:hidden">
        <Logo />
      </div>
      <h1 className="font-display text-[clamp(22px,2.4vw,30px)] font-bold">Your profile</h1>
      <ProfileForm />
      <AccountPanel />
      <Link
        href="/?tour=1"
        className="mt-10 flex items-center gap-3 rounded-2xl border border-line bg-surface p-3 pr-4 text-text hover:bg-raised hover:text-text"
      >
        <Tiko mood="wave" size={48} interactive={false} />
        <span className="flex flex-col">
          <span className="text-sm font-semibold">Replay the app tour</span>
          <span className="text-xs text-muted">Tiko hops you around the home page again.</span>
        </span>
      </Link>
    </main>
  );
}
