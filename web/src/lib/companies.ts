// Company practice: duels built only from topics on that company's
// aptitude test. Names match the company_tags set by supabase/seed.sql.
// comingSoon = true means questions aren't tagged yet; shown but disabled.
export const COMPANIES = [
  { slug: "tcs-nqt",       name: "TCS NQT",       blurb: "Numerical, reasoning and verbal",     emoji: "🔵", color: "#1565c0" },
  { slug: "infosys",       name: "Infosys",        blurb: "Puzzles, reasoning and maths",        emoji: "🟣", color: "#4527a0" },
  { slug: "accenture",     name: "Accenture",      blurb: "Abstract and critical reasoning",     emoji: "🟣", color: "#6a0dad" },
  { slug: "wipro",         name: "Wipro",          blurb: "Quant, analytical and verbal",        emoji: "🟢", color: "#1b5e20" },
  { slug: "cognizant",     name: "Cognizant",      blurb: "Quant, logical and English",          emoji: "🔵", color: "#0277bd" },
  { slug: "capgemini",     name: "Capgemini",      blurb: "Logic games, English and maths",      emoji: "🔵", color: "#01579b" },
  { slug: "hcl",           name: "HCL Tech",       blurb: "Analytical, reasoning and verbal",    emoji: "🟢", color: "#2e7d32" },
  { slug: "tech-mahindra", name: "Tech Mahindra",  blurb: "Quant, reasoning and verbal",         emoji: "🔴", color: "#b71c1c" },
  { slug: "hexaware",      name: "Hexaware",       blurb: "Numerical, verbal and reasoning",     emoji: "🟠", color: "#e65100" },
  { slug: "mphasis",       name: "Mphasis",        blurb: "Quant, logical and verbal",           emoji: "🟣", color: "#4a148c" },
  { slug: "deloitte",      name: "Deloitte",       blurb: "Numerical, logical and verbal",       emoji: "🟢", color: "#006064" },
] as const;

export type Company = (typeof COMPANIES)[number];

export const companyBySlug = (slug: string): Company | null => COMPANIES.find((c) => c.slug === slug) ?? null;
