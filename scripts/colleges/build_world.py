"""Builds the worldwide college list for Apticks from two free sources.

  ROR (Research Organization Registry), CC0: every active organisation of
  type "education" (universities and colleges, about 31,000). City names
  come from GeoNames (CC BY 4.0).
  Hipo university-domains-list, MIT: universities ROR doesn't have (matched
  on name within a country, and on web domain).

The 144 colleges already in Apticks are kept as they are (players use
them); each one that ROR also lists gets ROR's id, full name, aliases and
domains, so searching "Indian Institute of Technology Bombay" finds
"IIT Bombay", and ROR's own row is not added again.

  python3 -I build_world.py <ror csv> <hipo json> <current colleges json> <out dir>

Writes colleges-world.csv (for the Supabase table import), updates.sql (the
existing colleges' new columns) and report.txt (the matches, to check).
"""
import csv
import json
import os
import re
import sys
import unicodedata
from collections import defaultdict
from difflib import SequenceMatcher

ror_csv, hipo_json, current_json, out = sys.argv[1:5]
os.makedirs(out, exist_ok=True)
csv.field_size_limit(10**8)


def plain(s):
    """Lowercase ASCII words: accents dropped, & as and, no punctuation."""
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch)).lower()
    s = s.replace("&", " and ")
    s = re.sub(r"[^a-z0-9]+", " ", s)
    s = re.sub(r"^the ", "", s.strip())
    return re.sub(r"\s+", " ", s).strip()


def latin(s):
    """Only names a Latin keyboard can type go into the search aliases."""
    return all(ord(ch) < 0x250 or ch in "‘’“”–—·" for ch in s)


def values(field):
    """ROR CSV lists are "lang: value; lang: value"."""
    out = []
    for part in field.split("; "):
        part = part.strip()
        if not part:
            continue
        m = re.match(r"^([a-z]{2,3}|no_lang_code): (.*)$", part)
        out.append(m.group(2).strip() if m else part)
    return out


# ---- ROR ------------------------------------------------------------------------
ror = []
for d in csv.DictReader(open(ror_csv, newline="", encoding="utf-8")):
    if d["status"] != "active" or "education" not in d["types"].split("; "):
        continue
    name = d["names.types.ror_display"].strip()
    labels = values(d["names.types.label"])
    # A display name in another script gets its English label instead.
    if not latin(name):
        en = [l for l in labels if latin(l)]
        if not en:
            continue
        name = en[0]
    names = [name] + [x for x in labels + values(d["names.types.alias"]) + values(d["names.types.acronym"]) if latin(x)]
    seen, aliases = {plain(name)}, []
    for x in names[1:]:
        if plain(x) and plain(x) not in seen:
            seen.add(plain(x))
            aliases.append(x)
    city = values(d["locations.geonames_details.name"])
    country = values(d["locations.geonames_details.country_code"])
    ror.append({
        "ror": d["id"].rsplit("/", 1)[-1],
        "name": name,
        "aliases": aliases,
        "acronyms": [plain(a) for a in values(d["names.types.acronym"])],
        "city": city[0] if city else "",
        "country": (country[0] if country else "").upper(),
        "domains": [x.lower() for x in d["domains"].replace(",", ";").split(";") if x.strip()],
        # A hint of how well known it is: a Wikipedia page, and funding research.
        "weight": (1 if d["links.type.wikipedia"].strip() else 0) + (1 if "funder" in d["types"] else 0),
    })
ror_domains = {dom.strip() for r in ror for dom in r["domains"]}
ror_names = {(r["country"], plain(n)) for r in ror for n in [r["name"]] + r["aliases"]}

# ---- The colleges already in Apticks ------------------------------------------------
current = json.load(open(current_json))
by_country = defaultdict(list)
for r in ror:
    by_country[r["country"]].append(r)


def same_city(a, b):
    a, b = plain(a), plain(b)
    return bool(a and b) and (a == b or a[:5] == b[:5] or SequenceMatcher(None, a, b).ratio() > 0.8)


# Checked by hand: our short names whose ROR record the rules below miss.
MANUAL = {3: "007v4hf75", 4: "02d03ve54", 25: "04dp7tp96", 26: "026vtd268", 44: "01fczmh85",
          45: "034q1za58", 190: "013v3cc28", 207: "02zrtpp84", 230: "05h9eqy10", 231: "008b3ap06",
          245: "046sh6j17"}
ror_by_id = {r["ror"]: r for r in ror}


def match(c):
    """The ROR record for one of our colleges, or None."""
    if c["id"] in MANUAL:
        return ror_by_id.get(MANUAL[c["id"]])
    if c["name"] == "Other college":
        return None
    p, city = plain(c["name"]), c.get("city") or ""
    exact = [r for r in by_country["IN"] if p in {plain(n) for n in [r["name"]] + r["aliases"]}]
    if len(exact) == 1:
        return exact[0]
    if len(exact) > 1:
        local = [r for r in exact if same_city(r["city"], city)]
        return local[0] if len(local) == 1 else None
    # "VIT Vellore": the acronym, then the city.
    head = p.split(" ")[0]
    acr = [r for r in by_country["IN"] if head in r["acronyms"] and same_city(r["city"], city)]
    if len(acr) == 1:
        return acr[0]
    # "IIT Jodhpur" is "Indian Institute of Technology Jodhpur".
    long = None
    for short, full in EXPAND:
        if p.startswith(short + " "):
            long = full + p[len(short):]
            break
    if long:
        hit = [r for r in by_country["IN"] if long in {plain(n) for n in [r["name"]] + r["aliases"]}]
        if len(hit) == 1:
            return hit[0]
    # "Thapar Institute" inside "Thapar Institute of Engineering & Technology", same city.
    tight = p.replace(" ", "")
    inside = [r for r in by_country["IN"] if same_city(r["city"], city)
              and any(n.replace(" ", "").startswith(tight) for n in [plain(x) for x in [r["name"]] + r["aliases"]])]
    return inside[0] if len(inside) == 1 and len(tight) >= 8 else None


EXPAND = [("iiitdm", "indian institute of information technology design and manufacturing"),
          ("iiit", "indian institute of information technology"),
          ("iit", "indian institute of technology"),
          ("nit", "national institute of technology")]


updates, matched, report = [], set(), []
for c in current:
    r = match(c)
    if r:
        matched.add(r["ror"])
        updates.append((c["id"], r))
        report.append(f"MATCH {c['id']:>4} {c['name']:<45} = {r['name']} ({r['city']})")
    else:
        report.append(f"keep  {c['id']:>4} {c['name']}")

# ---- Rows to add --------------------------------------------------------------------
taken = {(plain(c["name"]), plain(c.get("city") or ""), "IN") for c in current}
rows = []


def add(name, city, country, ror_id, aliases, domains, source, weight):
    key = (plain(name), plain(city), country)
    if not plain(name) or key in taken:
        return
    taken.add(key)
    rows.append([name, city, country, ror_id, " | ".join(aliases), " ".join(domains), source, weight])


for r in ror:
    if r["ror"] in matched:
        continue
    add(r["name"], r["city"], r["country"], r["ror"], r["aliases"], r["domains"], "ror", r["weight"])
n_ror = len(rows)

for h in json.load(open(hipo_json)):
    name, cc = (h.get("name") or "").strip(), (h.get("alpha_two_code") or "").upper()
    doms = [x.lower().strip() for x in h.get("domains") or [] if x.strip()]
    if not name or not cc or (cc, plain(name)) in ror_names or any(x in ror_domains for x in doms):
        continue
    add(name, "", cc, "", [], doms, "hipo", 0)
n_hipo = len(rows) - n_ror

with open(os.path.join(out, "colleges-world.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["name", "city", "country", "ror_id", "aliases", "domains", "source", "weight"])
    w.writerows(rows)


def q(s):
    return "'" + s.replace("'", "''") + "'"


with open(os.path.join(out, "updates.sql"), "w", encoding="utf-8") as f:
    for cid, r in updates:
        aliases = [r["name"]] + r["aliases"]
        f.write(f"update public.colleges set ror_id = {q(r['ror'])}, aliases = {q(' | '.join(aliases))}, "
                f"domains = {q(' '.join(r['domains']))} where id = {cid} and ror_id is null;\n")

countries = sorted({r[2] for r in rows if r[2]} | {"IN"})
json.dump(countries, open(os.path.join(out, "countries.json"), "w"))
open(os.path.join(out, "report.txt"), "w").write("\n".join(report) + "\n")
print(f"ROR education: {len(ror)}; our colleges matched to ROR: {len(updates)} of {len(current)}")
print(f"rows to add: {len(rows)} ({n_ror} from ROR, {n_hipo} from Hipo); countries: {len(countries)}")
