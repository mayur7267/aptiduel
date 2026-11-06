import type { MetadataRoute } from "next";

// Makes the website installable: on Android, Chrome offers "Add to Home
// screen" and it opens full screen, like an app.
export default function manifest(): MetadataRoute.Manifest {
  return {
    id: "/",
    name: "Apticks: aptitude duels for placements",
    short_name: "Apticks",
    description: "Beat your friends at placement aptitude. 5 quick questions, live rating, college leaderboards.",
    start_url: "/",
    scope: "/",
    display: "standalone",
    orientation: "portrait",
    background_color: "#0b0e17",
    theme_color: "#0b0e17",
    categories: ["education", "games"],
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
      { src: "/icons/icon-maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
    shortcuts: [
      { name: "Daily challenge", short_name: "Daily", url: "/daily", icons: [{ src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" }] },
      { name: "Quick match", short_name: "Play", url: "/play", icons: [{ src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" }] },
    ],
  };
}
