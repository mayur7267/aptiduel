"use client";

import { useState, useSyncExternalStore } from "react";
import { siteUrl } from "@/lib/format";
import { Copy, Message, Share } from "./icons";

const noSubscribe = () => () => {};

// WhatsApp first, because that is where college groups live.
// `quiet` is the compact card version: link field on top, a dark
// WhatsApp button below, for cards that sit next to a lime one.
export function SharePanel({ code, text, quiet = false }: { code: string; text: string; quiet?: boolean }) {
  const url = siteUrl(`/c/${code}`);
  const [copied, setCopied] = useState(false);
  // false on the server, real value after hydration
  const canShare = useSyncExternalStore(noSubscribe, () => "share" in navigator, () => false);
  const whatsapp = `https://wa.me/?text=${encodeURIComponent(text)}`;

  async function copy() {
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard can be blocked; the link is still visible to copy by hand.
    }
  }

  const linkField = (
    <input
      id={`link-${code}`}
      readOnly
      value={url.replace(/^https?:\/\//, "")}
      onFocus={(e) => e.currentTarget.select()}
      className="h-11 min-w-0 flex-1 rounded-xl border border-[#2d3548] bg-ink px-3 text-sm text-soft"
    />
  );

  if (quiet) {
    return (
      <div className="flex flex-col gap-2.5">
        <label htmlFor={`link-${code}`} className="text-xs font-semibold text-muted">
          Your duel link
        </label>
        <div className="-mt-1 flex gap-2">
          {linkField}
          <button
            onClick={copy}
            aria-label={copied ? "Link copied" : "Copy link"}
            className="flex h-11 min-w-11 items-center justify-center rounded-xl border border-[#2d3548] bg-raised px-3 text-xs font-semibold hover:bg-line"
          >
            {copied ? "Copied" : <Copy size={18} />}
          </button>
        </div>
        <a
          href={whatsapp}
          target="_blank"
          rel="noopener noreferrer"
          className="flex h-12 items-center justify-center gap-2 rounded-[14px] border border-[#2d3548] bg-raised text-[15px] font-semibold text-text hover:bg-line hover:text-text"
        >
          <Message size={18} strokeWidth={2.2} />
          Share on WhatsApp
        </a>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2.5">
      <a
        href={whatsapp}
        target="_blank"
        rel="noopener noreferrer"
        className="flex h-14 items-center justify-center gap-2.5 rounded-2xl bg-lime text-base font-bold text-ink hover:bg-lime-hover hover:text-ink"
      >
        <Message size={20} strokeWidth={2.2} />
        Challenge on WhatsApp
      </a>
      <div className="flex gap-2">
        <label className="sr-only" htmlFor={`link-${code}`}>
          Challenge link
        </label>
        {linkField}
        <button
          onClick={copy}
          className="flex h-11 items-center gap-2 rounded-xl border border-line bg-raised px-4 text-sm font-semibold hover:bg-line"
        >
          <Copy size={16} />
          {copied ? "Copied" : "Copy"}
        </button>
        {canShare && (
          <button
            onClick={() => navigator.share({ title: "Apticks challenge", text, url }).catch(() => {})}
            aria-label="More ways to share"
            className="flex size-11 items-center justify-center rounded-xl border border-line bg-raised hover:bg-line"
          >
            <Share size={18} />
          </button>
        )}
      </div>
    </div>
  );
}
