import type { Metadata } from "next";
import { ProfileHub } from "./profile-hub";

export const metadata: Metadata = { title: "Your profile", robots: { index: false } };

export default function ProfilePage() {
  return (
    <main className="mx-auto w-full max-w-2xl px-4 pt-5 pb-12 sm:px-6 lg:pt-8">
      <ProfileHub />
    </main>
  );
}
