import Link from "next/link";
import { Tiko } from "@/components/tiko";
import { Logo } from "@/components/ui";

export default function NotFound() {
  return (
    <main className="mx-auto flex w-full max-w-xl flex-1 flex-col gap-6 px-4 pt-6 pb-16">
      <Logo />
      <div className="mt-10 flex flex-col gap-3">
        <Tiko mood="confused" size={110} className="self-start" />
        <h1 className="font-display text-2xl font-bold">Nothing here</h1>
        <p className="text-muted">This page or challenge link doesn&apos;t exist. If a friend sent you a challenge, ask them to send it again.</p>
        <Link href="/" className="mt-2 self-start rounded-2xl bg-lime px-6 py-3.5 font-bold text-ink hover:bg-lime-hover">
          Start a duel
        </Link>
      </div>
    </main>
  );
}
