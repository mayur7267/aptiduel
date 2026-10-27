import type { Metadata } from "next";
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
    </main>
  );
}
