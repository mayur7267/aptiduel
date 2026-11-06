import type { Metadata } from "next";
import Link from "next/link";
import { Email, LegalPage, P, Section } from "@/components/legal";
import { CONTACT_EMAIL } from "@/lib/contact";

export const metadata: Metadata = {
  title: "Help & contact",
  description: "Get help with Apticks, report a problem or send an idea.",
};

const FAQ: { q: string; a: React.ReactNode }[] = [
  {
    q: "I lost my progress. Can I get it back?",
    a: "Without an email, your account lives only in that browser or on that iPhone, so clearing browser data or deleting the app removes it. Save your account in Profile with your email and you can sign in anywhere with a one-time code and keep your rating.",
  },
  {
    q: "How do I delete my account?",
    a: "Open Profile → Account → Delete account, on the website or in the app. It removes your name, college and email. There are details in the privacy policy.",
  },
  {
    q: "How do I report a problem or a wrong question?",
    a: "In the app, tap Found a bug? in Profile, or shake your iPhone anywhere. On the website use Send feedback. When you review a duel, Report this question flags a single question. We read everything.",
  },
  {
    q: "How are scores and ratings worked out?",
    a: "A duel is 5 questions. A right answer scores 100 points, plus up to 50 for speed. The higher score wins and the faster player breaks a tie. Your rating goes up when you beat a rated opponent and down when you lose, by more for bigger upsets.",
  },
  {
    q: "Who are the opponents marked Bot?",
    a: "Computer players that make sure Quick Match always finds someone near your level. They are labelled, they never appear on leaderboards and their rating never changes.",
  },
  {
    q: "Are the company practice sets official?",
    a: "No. Apticks is an independent practice app. It isn't affiliated with, endorsed by or sponsored by any company it mentions. Company names are used only to say which topics a practice set covers. Questions are original, written in the style of placement aptitude tests.",
  },
  {
    q: "Does it cost anything?",
    a: "Apticks is free. There are no ads and no purchases.",
  },
];

export default function SupportPage() {
  return (
    <LegalPage title="Help & contact" lead="Something not working, or an idea to share? Write to us and a person will answer.">
      <section className="flex flex-col items-start gap-3 rounded-2xl border border-line bg-surface p-5">
        <h2 className="font-display text-lg font-bold">Email us</h2>
        <P>Include what you were doing and which device you use, and a screenshot if you can.</P>
        <a
          href={`mailto:${CONTACT_EMAIL}?subject=${encodeURIComponent("Apticks support")}`}
          className="flex min-h-12 items-center rounded-2xl bg-lime px-6 text-[15px] font-bold text-ink hover:bg-lime-hover"
        >
          {CONTACT_EMAIL}
        </a>
      </section>

      <Section title="Common questions">
        <div className="divide-y divide-line overflow-hidden rounded-2xl border border-line bg-surface">
          {FAQ.map(({ q, a }) => (
            <details key={q} className="group px-5 py-4">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-[15px] font-semibold">
                {q}
                <span aria-hidden="true" className="text-lime transition group-open:rotate-45">+</span>
              </summary>
              <p className="mt-2.5 text-[15px] leading-relaxed text-soft">{a}</p>
            </details>
          ))}
        </div>
      </Section>

      <P>
        Your data and your choices are covered in the{" "}
        <Link href="/privacy" className="font-semibold text-lime underline hover:text-lime-hover">
          privacy policy
        </Link>
        . To ask about it, write to <Email subject="Apticks privacy" />.
      </P>
    </LegalPage>
  );
}
