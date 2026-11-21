# The worldwide college list

About 34,000 colleges and universities in 224 countries, from two free
sources:

| Source | What | License |
|---|---|---|
| [ROR](https://ror.org) data dump ([Zenodo](https://zenodo.org/communities/ror-data)) | Every active organisation of type "education": name, aliases, acronyms, city, country, web domains | CC0. City names come from [GeoNames](https://www.geonames.org), CC BY 4.0 |
| [Hipo university-domains-list](https://github.com/Hipo/university-domains-list) | Universities ROR doesn't list (matched on name within a country and on web domain) | MIT (see HIPO-LICENSE.txt) |

## Rebuilding

```sh
# 1. The newest ROR dump (a zip with a CSV) and the Hipo list
curl -s "https://zenodo.org/api/communities/ror-data/records?sort=newest&size=1"   # the zip's link
curl -sLO https://raw.githubusercontent.com/Hipo/university-domains-list/master/world_universities_and_domains.json
# 2. The colleges already in Apticks (id, name, city), from the REST API
curl -s "$SUPABASE_URL/rest/v1/colleges?select=id,name,city&order=id" -H "apikey: $KEY" > current.json
# 3. Build
python3 -I build_world.py <ror csv> world_universities_and_domains.json current.json out/
```

`out/colleges-world.csv` is the rows to add, `out/updates.sql` the existing
colleges' ROR ids and aliases (pasted into migration 0027), and
`out/report.txt` which existing college matched which ROR record.

## Loading it

1. Paste `supabase/migrations/0027_world_colleges.sql` into the SQL editor and run it.
2. Table Editor → `colleges` → Insert → Import data from CSV → `colleges-world.csv`.
3. `analyze public.colleges;`

Existing colleges keep their ids, so players and leaderboards are untouched.
Older apps that load the whole table still see only the colleges in play.
