import type { Metadata } from "next";
import { Email, LegalPage, List, P, Section } from "@/components/legal";

export const metadata: Metadata = {
  title: "Privacy policy",
  description: "What Apticks collects, who can see it, and how to delete it.",
};

export default function PrivacyPage() {
  return (
    <LegalPage
      title="Privacy policy"
      updated="7 November 2026"
      lead="Apticks is a placement aptitude game for students: duels, a daily challenge and leaderboards, on the website and in the iPhone app. This page says what we collect, who can see it and how to remove it. It covers both."
    >
      <section className="flex flex-col gap-3 rounded-2xl border border-line bg-surface p-5">
        <h2 className="font-display text-lg font-bold">The short version</h2>
        <List>
          <li>You can play without giving us your name or email. A guest account is created for you automatically.</li>
          <li>We never sell your data. There are no ads, no advertising trackers and no analytics SDKs in the website or the app.</li>
          <li>Your name, college, graduation year and rating are visible to other players. Your email never is.</li>
          <li>
            You can delete your account yourself, any time: <span className="font-semibold text-text">Profile → Account → Delete account</span>, on
            the website and in the app.
          </li>
          <li>
            Questions or requests: <Email subject="Apticks privacy" />.
          </li>
        </List>
      </section>

      <Section title="What we collect">
        <List>
          <li>
            <span className="font-semibold text-text">A guest account.</span> The first time you open Apticks we create an anonymous account with a random
            ID. It lives in your browser or on your iPhone. If you clear your browser data or delete the app before saving your account, it can&apos;t be
            recovered.
          </li>
          <li>
            <span className="font-semibold text-text">Your profile.</span> A display name (you start as &quot;Player&quot; and a number), and if you choose
            to add them, your college and graduation year.
          </li>
          <li>
            <span className="font-semibold text-text">Your email address, only if you save your account or sign in.</span> We use it to send one-time sign-in
            codes. We don&apos;t send marketing email.
          </li>
          <li>
            <span className="font-semibold text-text">Your game activity.</span> The duels you play, your answers, scores and times, your rating, wins,
            streaks and Daily Challenge results.
          </li>
          <li>
            <span className="font-semibold text-text">Your test countdown, if you use it.</span> The company and date you set, and afterwards whether
            you cleared the test and how hard it felt. This stays private to you; we only look at it in aggregate, to see how practice relates to real
            results.
          </li>
          <li>
            <span className="font-semibold text-text">Feedback you send.</span> Your message, the email address if you give one, the app version, device or
            browser type, screen size and the page you were on, plus your name, rating, games played and college at that moment, so we can reproduce a
            problem.
          </li>
          <li>
            <span className="font-semibold text-text">Basic technical logs.</span> Our hosting and database providers record requests (such as IP address,
            browser and time) to keep the service secure and running.
          </li>
        </List>
        <P>
          We don&apos;t collect your location, contacts, photos, camera or microphone, health or payment information, and we don&apos;t use an advertising
          identifier. The website stores your guest session and a few preferences (like having seen the tour) in your browser&apos;s local storage; the app
          stores them on your iPhone. We don&apos;t use advertising or analytics cookies.
        </P>
      </Section>

      <Section title="What other players can see">
        <P>
          Apticks is social, so some of your profile is public to other players: your display name, college, graduation year, rating, games played, wins,
          streak, your recent wins and losses, your college rank and when you joined. It appears on leaderboards, in duel results and on your profile page,
          and a friend who opens a challenge link from you sees your name and college. In a duel, your opponent also sees your score, which questions you got
          right and how fast you answered. Your email, the option you picked on each question and your test countdown are never shown to other players.
          If you&apos;d rather stay low-key, use a nickname and leave the college blank.
        </P>
        <P>Practice opponents labelled &quot;Bot&quot; are computer players. They are not real people and never appear on leaderboards.</P>
      </Section>

      <Section title="How we use it">
        <List>
          <li>To run the game: matching you with opponents, scoring, ratings, streaks, leaderboards and your history.</li>
          <li>To sign you in and keep your account safe.</li>
          <li>To read and answer your feedback and fix what&apos;s broken.</li>
          <li>To understand, in counts, how Apticks is used: how many people play, come back and invite friends. This is not advertising or profiling.</li>
        </List>
        <P>We don&apos;t sell or rent your data, we don&apos;t show ads, and no decision about you is made by automated means beyond the game&apos;s own scoring.</P>
      </Section>

      <Section title="Who we share it with">
        <P>Only the services that run Apticks, and only so they can do that job:</P>
        <List>
          <li>
            <span className="font-semibold text-text">Supabase</span> hosts our database and sign-in, and sends the one-time sign-in codes.
          </li>
          <li>
            <span className="font-semibold text-text">Vercel</span> hosts the website.
          </li>
          <li>
            <span className="font-semibold text-text">An email provider (Gmail or Resend)</span> delivers your feedback to us.
          </li>
        </List>
        <P>
          These providers run servers in several countries, so your data may be processed outside India. We may also share information if the law
          requires it.
        </P>
      </Section>

      <Section title="Keeping and deleting your data">
        <P>
          We keep your data while your account exists. To delete it, open <span className="font-semibold text-text">Profile → Account → Delete account</span>{" "}
          on the website or in the app. This works for guest accounts too. When you delete:
        </P>
        <List>
          <li>Your name, college, graduation year and email are removed, and you are signed out for good.</li>
          <li>
            Duels you played stay in your opponents&apos; history, shown as &quot;Deleted player&quot;. Counts such as rating and games played stay on
            that anonymous record, which no longer points to you.
          </li>
          <li>
            Feedback you sent is kept so we can fix the problems you reported. It can include your name or email if you wrote them. Email us and we will
            remove it.
          </li>
        </List>
        <P>
          Prefer not to use the app? Email <Email subject="Delete my Apticks data" /> from the address on your account and we&apos;ll delete it for you.
        </P>
      </Section>

      <Section title="Your choices">
        <P>
          You can edit your name, college and graduation year in Profile at any time, and delete your account as above. You can also ask us what we hold
          about you, to correct it, or to delete it. Email <Email subject="Apticks privacy request" /> and we&apos;ll reply within 30 days. We handle
          personal data following the principles of India&apos;s Digital Personal Data Protection Act, 2023.
        </P>
      </Section>

      <Section title="Children">
        <P>
          Apticks is for students and job seekers. It isn&apos;t directed at children under 13, and we don&apos;t knowingly collect their data. If you think
          a child has given us information, email us and we&apos;ll delete it.
        </P>
      </Section>

      <Section title="Security">
        <P>
          Everything travels over HTTPS, and the database only lets you read and change your own records. No system is perfectly secure, so please
          don&apos;t put anything sensitive in your display name or feedback.
        </P>
      </Section>

      <Section title="Changes to this policy">
        <P>
          If we change this policy we&apos;ll update the date at the top, and tell you in the app or on the website when the change matters. Using Apticks
          after that means you accept the updated policy.
        </P>
      </Section>

      <Section title="Contact">
        <P>
          Apticks is run by an independent developer in India. Write to <Email subject="Apticks privacy" /> with any question about this policy or your
          data.
        </P>
      </Section>
    </LegalPage>
  );
}
