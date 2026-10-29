-- Records every file in supabase/migrations/ in Supabase's migration
-- history (Database → Migrations), so the dashboard matches this folder.
-- Run it in the SQL Editor after applying a migration by hand, and add a
-- line below for each new migration file. Safe to run more than once.

-- Migrations applied through the API get a timestamp version; use the
-- file's number instead, like the rest.
update supabase_migrations.schema_migrations s
   set version = left(s.name, 4)
 where s.name ~ '^\d{4}_'
   and s.version <> left(s.name, 4)
   and not exists (select 1 from supabase_migrations.schema_migrations x where x.version = left(s.name, 4));

insert into supabase_migrations.schema_migrations (version, name)
select m.version, m.name
  from (values
    ('0001', '0001_init'),
    ('0002', '0002_dashboard'),
    ('0003', '0003_bots'),
    ('0004', '0004_bot_pace'),
    ('0005', '0005_visual'),
    ('0006', '0006_fixes'),
    ('0007', '0007_stale_quick_match'),
    ('0008', '0008_company_tags'),
    ('0009', '0009_company_practice'),
    ('0010', '0010_audit_fixes'),
    ('0011', '0011_challenge_owner_view'),
    ('0012', '0012_feedback')
  ) as m(version, name)
 where not exists (select 1 from supabase_migrations.schema_migrations s where s.name = m.name)
   and not exists (select 1 from supabase_migrations.schema_migrations s where s.version = m.version);
