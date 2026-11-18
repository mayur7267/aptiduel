-- =====================================================================
-- Apticks · 0021_share_cards
-- Sharing a Daily result and a story card, and counting what sharing does.
--
-- 1. daily_share(code): the public side of a shared Daily run, for the
--    /d/<code> page and its preview image: who played, how they did
--    question by question (right or wrong only, never the questions),
--    and on which day. A Daily code can't open a challenge or a room
--    (those only take challenge and live codes), so the set stays private.
-- 2. share_events: one row per tap on a share button, by kind (daily,
--    story, challenge) and channel (whatsapp, share, copy, download).
-- 3. arrivals: how a brand-new visitor first came in, when it was a
--    shared Daily or story link. Lets the funnel numbers count them, or
--    leave them out when judging the first-time home screen.
-- 4. metrics.shares and metrics.arrivals: weekly shares, and the visitors
--    they brought in and how many of those played.
-- Safe to run more than once.
-- =====================================================================

-- 1. A shared Daily run --------------------------------------------------

create or replace function public.daily_share(p_code text) returns json
language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'name',     pr.display_name,
    'day',      ds.day,
    'today',    ds.day = public._today(),
    'correct',  p.correct,
    'score',    p.score,
    'total_ms', p.total_ms,
    'grid',     (select coalesce(json_agg(a.is_correct is true order by a.q_index), '[]'::json)
                   from public.answers a where a.player_id = p.id)
  )
  from public.duels d
  join public.duel_players p on p.duel_id = d.id and p.seat = 1 and not p.is_replay
  join public.profiles pr on pr.id = p.user_id
  join public.daily_sets ds on ds.set_id = d.set_id
  where d.code = upper(btrim(p_code)) and d.mode = 'daily'
    and p.finished_at is not null and pr.deleted_at is null
$$;

revoke all on function public.daily_share(text) from public;
grant execute on function public.daily_share(text) to anon, authenticated;

-- 2. Share taps ----------------------------------------------------------

create table if not exists public.share_events (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null check (kind in ('daily', 'story', 'challenge')),
  channel    text not null check (channel in ('whatsapp', 'share', 'copy', 'download')),
  duel_id    uuid references public.duels (id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists share_events_user_idx on public.share_events (user_id, created_at);
alter table public.share_events enable row level security;
revoke all on public.share_events from public, anon, authenticated;

create or replace function public.log_share(p_kind text, p_channel text, p_duel_id uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  did uuid := p_duel_id;
begin
  -- Only your own duels.
  if did is not null and not exists (
    select 1 from public.duel_players where duel_id = did and user_id = uid) then
    did := null;
  end if;
  -- A burst of taps on the same button is one share.
  if exists (
    select 1 from public.share_events
     where user_id = uid and kind = p_kind and channel = p_channel
       and duel_id is not distinct from did and created_at > now() - interval '10 seconds') then
    return;
  end if;
  insert into public.share_events (user_id, kind, channel, duel_id) values (uid, p_kind, p_channel, did);
end $$;

revoke all on function public.log_share(text, text, uuid) from public, anon;
grant execute on function public.log_share(text, text, uuid) to authenticated;

-- 3. How a newcomer came in ------------------------------------------------

create table if not exists public.arrivals (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  via        text not null check (via in ('daily', 'story')),
  code       text,
  created_at timestamptz not null default now()
);
alter table public.arrivals enable row level security;
revoke all on public.arrivals from public, anon, authenticated;

create or replace function public.note_arrival(p_via text, p_code text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
begin
  -- Only a newcomer's first way in: anyone who has played came some other way.
  if exists (select 1 from public.duel_players where user_id = uid) then
    return;
  end if;
  insert into public.arrivals (user_id, via, code)
  values (uid, p_via, nullif(upper(left(btrim(coalesce(p_code, '')), 12)), ''))
  on conflict (user_id) do nothing;
end $$;

revoke all on function public.note_arrival(text, text) from public, anon;
grant execute on function public.note_arrival(text, text) to authenticated;

-- 4. Metrics ---------------------------------------------------------------

create or replace view metrics.shares as
select date_trunc('week', se.created_at at time zone 'Asia/Kolkata')::date as week_of,
       se.kind,
       se.channel,
       count(*)                   as taps,
       count(distinct se.user_id) as sharers
  from public.share_events se
 group by 1, 2, 3;

create or replace view metrics.arrivals as
select date_trunc('week', a.created_at at time zone 'Asia/Kolkata')::date as week_of,
       a.via,
       count(*) as arrived,
       count(*) filter (where exists (select 1 from metrics.plays pl where pl.user_id = a.user_id)) as played
  from public.arrivals a
 group by 1, 2;

revoke all on all tables in schema metrics from public, anon, authenticated;
