// Company practice: duels built only from topics on that company's
// aptitude test. Names match the company_tags set by supabase/seed.sql.
export const COMPANIES = [
  { slug: "tcs-nqt", name: "TCS NQT", blurb: "Numerical, reasoning and verbal" },
  { slug: "infosys", name: "Infosys", blurb: "Puzzles, reasoning and maths" },
  { slug: "accenture", name: "Accenture", blurb: "Abstract and critical reasoning" },
  { slug: "wipro", name: "Wipro", blurb: "Quant, analytical and verbal" },
] as const;

export type Company = (typeof COMPANIES)[number];

export const companyBySlug = (slug: string): Company | null => COMPANIES.find((c) => c.slug === slug) ?? null;
