-- =====================================================================
-- Apticks · 0015_drives
-- Players can set the placement test they're preparing for: a company
-- and a date. Home counts down to it, shows how much they've practised
-- that company's topics and which ones they keep missing, and after the
-- date asks how it went.
--
-- Those answers, kept with the player's rating and practice at the time,
-- are what will later say what a rating means for clearing a company's
-- test ("players at 1450 cleared TCS NQT 70% of the time"). They are
-- private: only the team reads them.
-- Run after 0014. Safe to run more than once.
-- =====================================================================

alter table public.profiles add column if not exists drive_company text;
alter table public.profiles add column if not exists drive_on date;

create table if not exists public.drive_results (
  id           bigserial primary key,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  company      text not null,
  drive_on     date not null,
  cleared      text not null check (cleared in ('yes', 'no', 'skipped')),
  difficulty   text check (difficulty in ('easier', 'same', 'harder')),
  -- The player when they answered.
  rating       int not null,
  games_played int not null,
  practised    int not null,  -- questions on this company's topics in the 30 days before
  accuracy     int,           -- percent right of those
  created_at   timestamptz not null default now(),
  unique (user_id, company, drive_on)
);
alter table public.drive_results enable row level security;
revoke all on public.drive_results from anon, authenticated;

-- How a player has done on a company's topics in the last 30 days.
create or replace function public._drive_practice(p_user uuid, p_company text,
  out practised int, out accuracy int, out weak_topics json)
language sql stable security definer set search_path = '' as $$
  with mine as (
    select q.topic, a.is_correct
      from public.answers a
      join public.duel_players dp on dp.id = a.player_id
      join public.questions q on q.id = a.question_id
     where dp.user_id = p_user and not dp.is_replay
       and a.answered_at is not null and a.answered_at > now() - interval '30 days'
       and p_company = any(q.company_tags)
  )
  select (select count(*)::int from mine),
         (select round(100.0 * count(*) filter (where is_correct) / nullif(count(*), 0))::int from mine),
         -- Up to three topics they get right less than 70% of the time.
         coalesce((select json_agg(topic order by acc, n desc) from (
                     select topic, avg(is_correct::int) as acc, count(*) as n
                       from mine group by topic
                      having count(*) >= 2 and avg(is_correct::int) < 0.7
                      order by avg(is_correct::int), count(*) desc
                      limit 3) w), '[]'::json)
$$;

-- The player's next test, with their practice for it.
create or replace function public.my_drive() returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  p public.profiles;
  done public.drive_results;
  practice record;
begin
  select * into p from public.profiles where id = uid;
  if p.drive_company is null then
    return json_build_object('company', null);
  end if;
  select * into done from public.drive_results
   where user_id = uid and company = p.drive_company and drive_on = p.drive_on;
  select * into practice from public._drive_practice(uid, p.drive_company);

  return json_build_object(
    'company',     p.drive_company,
    'drive_on',    p.drive_on,
    'days_left',   p.drive_on - public._today(),
    'answered',    done.id is not null,
    'cleared',     done.cleared,
    'practised',   practice.practised,
    'accuracy',    practice.accuracy,
    'weak_topics', practice.weak_topics
  );
end $$;

-- Set (or, with no company, clear) the test you're preparing for. A date
-- up to 30 days back is fine, so a test that just happened can be
-- reported.
create or replace function public.set_drive(p_company text, p_drive_on date) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  company text := nullif(btrim(p_company), '');
begin
  if company is null then
    update public.profiles set drive_company = null, drive_on = null where id = uid;
    return public.my_drive();
  end if;
  if length(company) not between 2 and 40 then
    raise exception 'Company names are 2 to 40 characters.';
  end if;
  if p_drive_on is null or p_drive_on < public._today() - 30 or p_drive_on > public._today() + 400 then
    raise exception 'Pick a date within the next year.';
  end if;
  update public.profiles set drive_company = company, drive_on = p_drive_on where id = uid;
  return public.my_drive();
end $$;

-- How the test went, on or after its date. Answering again replaces it.
create or replace function public.submit_drive_result(p_cleared text, p_difficulty text default null) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  p public.profiles;
  practice record;
begin
  select * into p from public.profiles where id = uid;
  if p.drive_company is null or p.drive_on > public._today() then
    raise exception 'Tell us after your test.';
  end if;
  if p_cleared is null or p_cleared not in ('yes', 'no', 'skipped') then
    raise exception 'Pick an answer.';
  end if;
  if p_difficulty is not null and p_difficulty not in ('easier', 'same', 'harder') then
    raise exception 'Pick an answer.';
  end if;
  select * into practice from public._drive_practice(uid, p.drive_company);

  insert into public.drive_results
    (user_id, company, drive_on, cleared, difficulty, rating, games_played, practised, accuracy)
  values
    (uid, p.drive_company, p.drive_on, p_cleared, case when p_cleared = 'skipped' then null else p_difficulty end,
     p.rating, p.games_played, practice.practised, practice.accuracy)
  on conflict (user_id, company, drive_on) do update
     set cleared = excluded.cleared, difficulty = excluded.difficulty, rating = excluded.rating,
         games_played = excluded.games_played, practised = excluded.practised,
         accuracy = excluded.accuracy, created_at = now();
  return public.my_drive();
end $$;

revoke all on function public._drive_practice(uuid, text) from public, anon, authenticated;
revoke all on function public.my_drive(), public.set_drive(text, date), public.submit_drive_result(text, text)
  from public, anon;
grant execute on function public.my_drive(), public.set_drive(text, date), public.submit_drive_result(text, text)
  to authenticated;
