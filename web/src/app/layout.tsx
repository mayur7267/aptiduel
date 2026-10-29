import type { Metadata, Viewport } from "next";
import { Caveat, Inter, JetBrains_Mono, Unbounded } from "next/font/google";
import { Suspense } from "react";
import { Companion } from "@/components/companion";
import { FeedbackDialog } from "@/components/feedback-dialog";
import "./globals.css";

const inter = Inter({ variable: "--font-inter", subsets: ["latin"] });
const unbounded = Unbounded({
  variable: "--font-unbounded",
  subsets: ["latin"],
  weight: ["500", "700"],
});
// Scoreboard numbers: timers, scores and ratings.
const jetbrains = JetBrains_Mono({ variable: "--font-jetbrains", subsets: ["latin"], weight: ["500", "700"] });
// Handwriting, for the red-pen notes on the profile page.
const caveat = Caveat({ variable: "--font-caveat", subsets: ["latin"], weight: ["600", "700"] });

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"),
  title: { default: "Apticks: aptitude duels for placements", template: "%s · Apticks" },
  description:
    "Beat your friends at placement aptitude. 5 quick questions, live rating, college leaderboards.",
};

export const viewport: Viewport = {
  themeColor: "#0b0e17",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${inter.variable} ${unbounded.variable} ${jetbrains.variable} ${caveat.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col font-sans">
        {children}
        {/* Tiko stays with the player across pages (it reads the URL, hence Suspense). */}
        <Suspense fallback={null}>
          <Companion />
        </Suspense>
        <FeedbackDialog />
      </body>
    </html>
  );
}
