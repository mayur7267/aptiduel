"use client";

import Link from "next/link";
import { useEffect, useLayoutEffect, useRef, useState, type ReactNode } from "react";
import { api, type Subjects } from "@/lib/api";
import { CODE_LANGS, SUBJECT_TABS, useCodeLang, useSubjectTab, type CodeLang, type Subject, type SubjectTab } from "@/lib/subjects";
import { Bolt } from "@/components/icons";

// Cards ease in one after another (see each card's animationDelay).
export const CARD =
  "relative isolate flex flex-col gap-3.5 overflow-hidden rounded-[22px] border-2 p-[22px] sticker md:min-h-[244px] motion-safe:animate-rise";

// Quick Match in a subject. Four big binder tabs, one colour each, so
// the four subjects read at a glance; the open one lifts into the card.
// Playing stays one tap: the card and its one button follow the tab
// (remembered). Live subjects are solid, coming-soon ones are tinted.
// base: the closed tab's background, under everything; fill: the open
// colour that rises over it; on/off: border and text, open or closed
// (never both, or the closed text colour can win and vanish on the fill).
type Look = { glyph: string; base: string; fill: string; on: string; off: string };
const TAB: Record<SubjectTab, Look> = {
  aptitude: { glyph: "Σ", base: "bg-lime-tint", fill: "bg-lime", on: "border-[#9fc41f] text-ink", off: "border-[#3d4a14] text-lime" },
  coding: { glyph: "</>", base: "bg-violet-tint", fill: "bg-violet", on: "border-[#8676e6] text-ink", off: "border-violet-strong text-violet" },
  english: { glyph: "Aa", base: "bg-orange-tint", fill: "bg-orange", on: "border-[#d4683a] text-ink", off: "border-[#5a3420] text-orange" },
  gk: { glyph: "?", base: "bg-[#0e1a21]", fill: "bg-[#10222c]", on: "border-[#2f6f8f] text-[#6cc7ff]", off: "border-[#1f3a48] text-[#6cc7ff]/80" },
};

const PLAY_LOOK = {
  aptitude: {
    card: "border-[#9fc41f] bg-lime bg-[repeating-linear-gradient(135deg,transparent_0_14px,rgb(11_14_23/0.035)_14px_28px)] text-ink [--pop:#5f7710]",
    tag: "1V1 · RATED",
    sticker: "VS",
    sub: "text-lime-ink",
    blurb: "Quant and reasoning, the way placement tests ask. Race a player near your rating: 5 questions, about 3 min.",
  },
  coding: {
    card: "border-[#8676e6] bg-violet bg-[repeating-linear-gradient(90deg,transparent_0_22px,rgb(11_14_23/0.05)_22px_23px)] text-ink [--pop:#4b3fa6]",
    tag: "1V1 · CODING",
    sticker: "</>",
    sub: "text-[#241d5c]",
    blurb: "Read the code, call the output. 5 programs in the language you know, about 4 min.",
  },
  english: {
    card: "border-[#d4683a] bg-orange bg-[repeating-linear-gradient(45deg,transparent_0_16px,rgb(11_14_23/0.04)_16px_17px)] text-ink [--pop:#9c4a1f]",
    tag: "1V1 · ENGLISH",
    sticker: "Aa",
    sub: "text-[#4a1f08]",
    blurb: "Vocabulary, grammar and usage, the way placement tests ask. 5 questions, about 3 min.",
  },
} as const;

// What each live subject's Play button and sticker look like.
const PLAY_ACCENT: Record<Subject, { sticker: string; pop: string; bolt: string; href: string }> = {
  aptitude: { sticker: "bg-ink text-base text-lime [--pop:#5f7710] sm:text-lg", pop: "[--pop:#5f7710]", bolt: "text-lime", href: "/play" },
  coding: { sticker: "bg-ink font-mono text-sm text-violet [--pop:#4b3fa6] sm:text-base", pop: "[--pop:#4b3fa6]", bolt: "text-violet", href: "/play/coding" },
  english: { sticker: "bg-ink text-base text-orange [--pop:#9c4a1f] sm:text-lg", pop: "[--pop:#9c4a1f]", bolt: "text-orange", href: "/play/english" },
};

const SOON = {
  gk: {
    card: "border-[#2f6f8f] bg-[#10222c] [--pop:#0b1a22]",
    accent: "text-[#6cc7ff]",
    blurb: "Static GK and current affairs for bank and government exams.",
  },
} as const;

export function QuickMatchCard() {
  const [tab, setTab] = useSubjectTab();
  const [lang, setLang] = useCodeLang();
  // undefined while loading; null when Coding isn't live yet (tab hidden).
  const [subjects, setSubjects] = useState<Subjects | null | undefined>(undefined);
  useEffect(() => {
    let active = true;
    // A failed call keeps Coding visible (just without your rating);
    // only a database without 0022 hides it.
    api.mySubjects().then((s) => active && setSubjects(s), () => {});
    return () => {
      active = false;
    };
  }, []);
  return <SubjectCard tab={tab} onTab={setTab} lang={lang} onLang={setLang} subjects={subjects} />;
}

export function SubjectCard({
  tab,
  onTab: setTab,
  lang,
  onLang: setLang,
  subjects,
}: {
  tab: SubjectTab;
  onTab: (t: SubjectTab) => void;
  lang: CodeLang;
  onLang: (l: CodeLang) => void;
  subjects: Subjects | null | undefined;
}) {
  const tabs = SUBJECT_TABS.filter((t) => t.id !== "coding" || subjects !== null);
  const current = tabs.some((t) => t.id === tab) ? tab : "aptitude";

  return (
    <div data-tour="quick" className="flex flex-col md:row-span-2">
      <SubjectTabs tabs={tabs} current={current} onPick={setTab} />
      <SubjectStage current={current} tabs={tabs}>
        {(t) =>
          t === "gk" ? (
            <SoonPanel which={t} onBack={() => setTab("aptitude")} />
          ) : (
            <PlayPanel subject={t} lang={lang} setLang={setLang} rating={t === "aptitude" ? undefined : subjects?.[t]} />
          )
        }
      </SubjectStage>
    </div>
  );
}

// Picking a subject, like a theme switch: the tab you tap fills with its
// colour from the bottom up, and the colour pours down out of the tab into
// the card below, a soft-edged (gradient) shape that first runs down like
// a pour, then widens until it fills the whole card. The old card stays
// underneath until covered. Plain element animations (a moving mask), so
// it plays the same in every browser; with reduced motion it's instant.
const POUR_MS = 650;
const RISE_MS = 260;
// Solid up to this share of the shape's radius, then fading out: the
// gradient edge of the pour.
const CORE = 0.62;

const reducedMotion = () =>
  typeof window === "undefined" || window.matchMedia("(prefers-reduced-motion: reduce)").matches;

export function SubjectStage({
  current,
  tabs = SUBJECT_TABS,
  children,
}: {
  current: SubjectTab;
  tabs?: typeof SUBJECT_TABS;
  children: (t: SubjectTab) => ReactNode;
}) {
  const [shown, setShown] = useState(current);
  const [under, setUnder] = useState<SubjectTab | null>(null);
  // After the first switch the cards stop doing their page-load rise.
  const [switched, setSwitched] = useState(false);
  if (shown !== current) {
    setShown(current);
    setSwitched(true);
    setUnder(reducedMotion() ? null : shown);
  }
  const stage = useRef<HTMLDivElement>(null);
  const top = useRef<HTMLDivElement>(null);

  useLayoutEffect(() => {
    if (!under || !stage.current || !top.current) return;
    const box = stage.current.getBoundingClientRect();
    const tab = stage.current.parentElement
      ?.querySelector<HTMLElement>('[role="tab"][aria-selected="true"]')
      ?.getBoundingClientRect();
    const el = top.current;
    const w = box.width;
    const h = box.height;
    // The pour starts at the middle of the tab's bottom edge (the card's top).
    const x = tab ? tab.left + tab.width / 2 - box.left : w / 2;
    const tabW = tab ? tab.width : w / 4;
    // An ellipse centred there: tall and narrow while it runs down, then wide
    // enough that its solid core covers the furthest corner.
    const at = (sw: number, sh: number) => ({
      size: `${Math.round(sw)}px ${Math.round(sh)}px`,
      pos: `${Math.round(x - sw / 2)}px ${Math.round(-sh / 2)}px`,
    });
    const steps = [
      at(tabW * 0.6, 0),
      at(tabW * 1.5, h * 1.3),
      at((3.2 * Math.max(x, w - x)) / CORE, (3.2 * h) / CORE),
    ];
    const mask = `radial-gradient(closest-side, #000 ${CORE * 100}%, transparent 100%)`;
    el.style.setProperty("mask-image", mask);
    el.style.setProperty("-webkit-mask-image", mask);
    el.style.setProperty("mask-repeat", "no-repeat");
    el.style.setProperty("-webkit-mask-repeat", "no-repeat");
    const frame = (s: { size: string; pos: string }, offset?: number) => ({
      maskSize: s.size,
      maskPosition: s.pos,
      WebkitMaskSize: s.size,
      WebkitMaskPosition: s.pos,
      ...(offset === undefined ? {} : { offset }),
    });
    const pour = el.animate([frame(steps[0]), frame(steps[1], 0.38), frame(steps[2])], {
      duration: POUR_MS,
      easing: "cubic-bezier(0.5, 0, 0.25, 1)",
    });
    const unmask = () => {
      for (const p of ["mask-image", "-webkit-mask-image", "mask-repeat", "-webkit-mask-repeat"]) el.style.removeProperty(p);
    };
    pour.onfinish = () => {
      unmask();
      setUnder(null);
    };
    return () => {
      pour.cancel();
      unmask();
    };
  }, [under]);

  const still = switched ? "[&>*]:animate-none!" : "";
  return (
    <div ref={stage} className="relative grid flex-1">
      {under && (
        <div aria-hidden="true" inert className="pointer-events-none absolute inset-0 flex flex-col [&>*]:animate-none!">
          {children(under)}
        </div>
      )}
      <div ref={top} className={`relative flex flex-col [grid-area:1/1] ${still}`}>
        {children(shown)}
      </div>
      {/* Every subject's card again, invisible, in the same grid cell: the
          tallest sets the height, so all four are the same size and switching
          never jumps. Last, so ids on the page resolve to the real card. */}
      {tabs.map((t) => (
        <div key={t.id} aria-hidden="true" inert className="invisible flex flex-col [grid-area:1/1] [&>*]:animate-none!">
          {children(t.id)}
        </div>
      ))}
    </div>
  );
}

// The four binder tabs. Shared by home and the first-visit screen.
export function SubjectTabs({
  tabs = SUBJECT_TABS,
  current,
  onPick,
}: {
  tabs?: typeof SUBJECT_TABS;
  current: SubjectTab;
  onPick: (t: SubjectTab) => void;
}) {
  const fills = useRef(new Map<SubjectTab, HTMLSpanElement>());
  const last = useRef(current);
  useLayoutEffect(() => {
    if (last.current === current) return;
    last.current = current;
    if (reducedMotion()) return;
    fills.current
      .get(current)
      ?.animate([{ transform: "scaleY(0)" }, { transform: "scaleY(1)" }], { duration: RISE_MS, easing: "cubic-bezier(0.33, 1, 0.68, 1)" });
  }, [current]);

  return (
    <div
      role="tablist"
      aria-label="Subject"
      data-tour="subjects"
      className="grid items-end gap-1.5 px-5 pt-2 sm:px-6"
      style={{ gridTemplateColumns: `repeat(${tabs.length}, minmax(0, 1fr))` }}
    >
      {tabs.map((t) => {
        const on = t.id === current;
        const look = TAB[t.id];
        return (
          <button
            key={t.id}
            role="tab"
            aria-selected={on}
            aria-label={t.soon ? `${t.label}, coming soon` : t.label}
            onClick={() => onPick(t.id)}
            className={`relative isolate flex flex-col items-center justify-center gap-1 rounded-t-2xl border-2 border-b-0 transition-[height,color,border-color] duration-200 ${look.base} ${
              on ? `z-10 -mb-[2px] h-[62px] sm:h-[68px] ${look.on}` : `h-[52px] sm:h-[58px] hover:h-[56px] sm:hover:h-[62px] ${look.off}`
            }`}
          >
            <span
              ref={(el) => {
                if (el) fills.current.set(t.id, el);
              }}
              aria-hidden="true"
              className={`absolute inset-0 -z-10 origin-bottom rounded-t-[14px] ${look.fill} ${on ? "" : "scale-y-0"}`}
            />
            <span aria-hidden="true" className="font-mono text-[17px] leading-none font-bold sm:text-[19px]">
              {look.glyph}
            </span>
            <span className="text-[12px] leading-none font-bold sm:text-[13px]">{t.label}</span>
            {t.soon && (
              <span className="absolute -top-2 right-1 rotate-6 rounded-[5px] bg-ink px-1 py-px font-mono text-[8px] font-bold tracking-wider text-soft ring-1 ring-line-strong">
                SOON
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}

const PANEL =
  "relative isolate flex flex-1 flex-col gap-3 overflow-hidden rounded-[22px] border-2 p-4 sticker motion-safe:animate-rise sm:gap-4 sm:p-5 md:p-6";

function Sticker({ text, className }: { text: string; className: string }) {
  return (
    <span
      aria-hidden="true"
      className={`sticker flex size-11 shrink-0 rotate-6 items-center justify-center rounded-xl font-display font-bold sm:size-14 sm:rounded-2xl ${className}`}
    >
      {text}
    </span>
  );
}

function Heading({ tag, tagClass, title, blurb, blurbClass }: { tag: string; tagClass: string; title: string; blurb: string; blurbClass: string }) {
  return (
    <div className="flex min-w-0 flex-col gap-1">
      <span className={`-rotate-2 self-start rounded-md px-1.5 py-0.5 font-mono text-[10px] font-bold tracking-wider ${tagClass}`}>{tag}</span>
      <h2 className="font-display text-[22px] leading-tight font-bold md:text-[28px]">{title}</h2>
      <p className={`text-[13px] leading-snug font-medium sm:text-sm ${blurbClass}`}>{blurb}</p>
    </div>
  );
}

function PlayPanel({
  subject,
  lang,
  setLang,
  rating,
}: {
  subject: Subject;
  lang: CodeLang;
  setLang: (l: CodeLang) => void;
  rating?: { rating: number; games: number };
}) {
  const look = PLAY_LOOK[subject];
  const accent = PLAY_ACCENT[subject];
  const coding = subject === "coding";
  return (
    <div className={`${PANEL} ${look.card}`}>
      <div className="flex items-start justify-between gap-3">
        <Heading tag={look.tag} tagClass="bg-ink text-lime" title="Quick Match" blurb={look.blurb} blurbClass={look.sub} />
        <Sticker text={look.sticker} className={accent.sticker} />
      </div>
      <Peek subject={subject} lang={lang} />
      {coding && (
        <div role="radiogroup" aria-label="Show the code in" className="flex flex-wrap gap-1">
          {CODE_LANGS.map((l) => {
            const on = l.id === lang;
            return (
              <button
                key={l.id}
                role="radio"
                aria-checked={on}
                onClick={() => setLang(l.id)}
                className={`h-7 rounded-md px-2 font-mono text-[11px] font-bold transition-colors sm:h-8 sm:px-2.5 sm:text-xs ${
                  on ? "bg-ink text-violet" : "bg-ink/10 text-ink hover:bg-ink/20"
                }`}
              >
                {l.label}
              </button>
            );
          })}
        </div>
      )}
      <div className="mt-auto flex flex-wrap items-center gap-x-4 gap-y-2">
        <Link
          href={accent.href}
          className={`pressable flex h-11 items-center gap-2 rounded-xl bg-ink px-4 text-sm font-bold text-text hover:text-text sm:h-12 sm:px-5 sm:text-[15px] ${accent.pop}`}
        >
          <Bolt size={16} strokeWidth={2.4} className={accent.bolt} />
          Find opponent
        </Link>
        {rating && rating.games > 0 && (
          <span className={`font-mono text-xs font-bold ${look.sub}`}>Rating {rating.rating}</span>
        )}
      </div>
    </div>
  );
}

function SoonPanel({ which, onBack }: { which: "gk"; onBack: () => void }) {
  const soon = SOON[which];
  return (
    <div className={`${PANEL} text-text ${soon.card}`}>
      <div className="flex items-start justify-between gap-3">
        <Heading
          tag="COMING SOON"
          tagClass={`bg-ink ${soon.accent}`}
          title="GK"
          blurb={soon.blurb}
          blurbClass="text-soft"
        />
        <Sticker text={TAB[which].glyph} className={`bg-ink text-base sm:text-lg [--pop:#0b0e17] ${soon.accent}`} />
      </div>
      <Peek subject={which} />
      <button
        onClick={onBack}
        className="pressable mt-auto flex h-11 items-center gap-2 self-start rounded-xl border-2 border-line bg-ink px-4 text-sm font-bold text-text [--pop:#0b0e17] sm:h-12 sm:px-5"
      >
        <Bolt size={16} strokeWidth={2.4} className="text-lime" />
        Play Aptitude meanwhile
      </button>
    </div>
  );
}

// A taste of the subject, on screens with room for it: one sample, in the
// subject's own style. Coding follows the chosen language.
const CODE_PEEK: Record<CodeLang, string> = {
  c: 'int s = 0;\nfor (int i = 1; i <= 4; i++) s += i;\nprintf("%d", s);',
  cpp: "int s = 0;\nfor (int i = 1; i <= 4; i++) s += i;\ncout << s;",
  java: "int s = 0;\nfor (int i = 1; i <= 4; i++) s += i;\nSystem.out.print(s);",
  python: "s = 0\nfor i in range(1, 5):\n    s += i\nprint(s)",
  pseudo: "Integer s = 0\nfor i = 1 to 4\n  s = s + i\nend for\nprint s",
};

const SAMPLE = {
  aptitude: { q: "A 120 m train passes a pole in 6 seconds. Its speed?", opts: ["54 km/h", "72 km/h", "60 km/h", "80 km/h"] },
  english: { q: "Pick the word closest in meaning to CANDID.", opts: ["Frank", "Sly", "Stiff", "Vague"] },
  gk: { q: "Which river is called the Sorrow of Bihar?", opts: ["Kosi", "Gandak", "Son", "Ganga"] },
} as const;

function Peek({ subject, lang = "c" }: { subject: SubjectTab; lang?: CodeLang }) {
  if (subject === "coding") {
    return (
      <div aria-hidden="true" className="relative hidden rounded-xl bg-ink px-3.5 py-3 sm:block">
        <pre className="font-mono text-[12px] leading-[1.6] whitespace-pre text-soft">{CODE_PEEK[lang]}</pre>
        <span className="absolute top-2.5 right-3 rounded-md bg-violet-tint px-1.5 py-0.5 font-mono text-[10px] font-bold text-violet">
          prints ?
        </span>
      </div>
    );
  }
  const sample = SAMPLE[subject];
  return (
    <div aria-hidden="true" className={`hidden flex-col gap-2.5 rounded-xl bg-ink px-3.5 py-3 sm:flex ${subject === "gk" ? "opacity-70" : ""}`}>
      <p className="text-[13px] leading-snug font-semibold text-text">{sample.q}</p>
      <div className="flex flex-wrap gap-1.5">
        {sample.opts.map((o, i) => (
          <span key={o} className="flex items-center gap-1.5 rounded-full border border-line px-2 py-0.5 text-[11px] text-soft">
            <span className="font-mono font-bold text-muted">{"ABCD"[i]}</span>
            {o}
          </span>
        ))}
      </div>
    </div>
  );
}
