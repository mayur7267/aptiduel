-- =====================================================================
-- Apticks · 0025_subject_ranks
-- A rating and a leaderboard per subject. Profiles show the player's
-- Aptitude, Coding and English ratings side by side, and the Ranks tab
-- has a board for each subject (college and India).
--
-- Also: a board's "this week" change used to add up rating changes from
-- every subject; it now counts only that board's subject. Aptitude games
-- no longer count Coding and English games.
--
-- The calls the apps already out make (leaderboard(p_scope, p_limit),
-- get_profile) keep their shape: Aptitude, as before.
-- Safe to run more than once.
-- =====================================================================

-- Rating change since a moment, in one subject.
create or replace function public._week_delta(p_user uuid, p_since timestamptz, p_subject text) returns int
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(dp.rating_after - dp.rating_before), 0)::int
    from public.duel_players dp
    join public.duels d on d.id = dp.duel_id
    left join public.duel_sets s on s.id = d.set_id
   where dp.user_id = p_user and not dp.is_replay and dp.rating_after is not null
     and dp.finished_at >= p_since
     and coalesce(s.subject, 'aptitude') = p_subject
$$;

create or replace function public._week_delta(p_user uuid, p_since timestamptz) returns int
language sql stable security definer set search_path = '' as $$
  select public._week_delta(p_user, p_since, 'aptitude')
$$;

-- A player's rating and games in every subject. profiles.games_played
-- counts every subject, so Aptitude's games are what's left.
create or replace function public._subjects_json(p_user uuid) returns json
language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'aptitude', json_build_object(
                  'rating', p.rating,
                  'games',  greatest(0, p.games_played - coalesce((select sum(games) from public.subject_ratings where user_id = p.id), 0))::int),
    'coding',   json_build_object(
                  'rating', public._rating(p.id, 'coding'),
                  'games',  coalesce((select games from public.subject_ratings where user_id = p.id and subject = 'coding'), 0)),
    'english',  json_build_object(
                  'rating', public._rating(p.id, 'english'),
                  'games',  coalesce((select games from public.subject_ratings where user_id = p.id and subject = 'english'), 0)))
    from public.profiles p
   where p.id = p_user
$$;

create or replace function public.my_subjects() returns json
language plpgsql security definer set search_path = '' as $$
begin
  return public._subjects_json(public._require_player());
end $$;

-- Leaderboards ----------------------------------------------------------

-- leaderboard (0014) in a subject. Aptitude ranks everyone who has
-- played, as before; Coding and English rank players with at least one
-- rated game in that subject.
create or replace function public.leaderboard(p_scope text, p_limit int, p_subject text)
returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  my_college int;
  week_start timestamptz :=
    date_trunc('week', now() at time zone 'Asia/Kolkata') at time zone 'Asia/Kolkata';
  r json;
begin
  if p_scope not in ('college', 'india') then
    raise exception 'Unknown leaderboard.';
  end if;
  if p_subject is null or p_subject not in ('aptitude', 'coding', 'english') then
    raise exception 'Unknown subject.';
  end if;
  select college_id into my_college from public.profiles where id = uid;

  with players as (
    select pr.id, pr.display_name, pr.grad_year, pr.college_id,
           case when p_subject = 'aptitude' then pr.rating else sr.rating end as rating
      from public.profiles pr
      left join public.subject_ratings sr on sr.user_id = pr.id and sr.subject = p_subject
     where not pr.is_bot
       and pr.deleted_at is null
       and (p_scope = 'india' or pr.college_id = my_college)
       and case when p_subject = 'aptitude' then pr.last_played_on is not null
                else coalesce(sr.games, 0) > 0 end
  ), ranked as (
    select x.*, c.name as college, rank() over (order by x.rating desc) as rnk
      from players x
      left join public.colleges c on c.id = x.college_id
  ), shown as (
    select * from ranked order by rnk, display_name limit least(greatest(p_limit, 1), 100)
  )
  select json_build_object(
           'scope',   p_scope,
           'subject', p_subject,
           'college', (select name from public.colleges where id = my_college),
           'players', (select count(*) from ranked),
           'rows',    coalesce((select json_agg(json_build_object(
                                         'id',         x.id,
                                         'rank',       x.rnk,
                                         'name',       x.display_name,
                                         'rating',     x.rating,
                                         'college',    x.college,
                                         'grad_year',  x.grad_year,
                                         'week_delta', public._week_delta(x.id, week_start, p_subject),
                                         'is_me',      x.id = uid)
                                       order by x.rnk, x.display_name)
                                  from shown x),
                               '[]'::json),
           'me',      (select json_build_object(
                                'id',         x.id,
                                'rank',       x.rnk,
                                'name',       x.display_name,
                                'rating',     x.rating,
                                'college',    x.college,
                                'grad_year',  x.grad_year,
                                'week_delta', public._week_delta(x.id, week_start, p_subject),
                                'is_me',      true)
                         from ranked x where x.id = uid)
         ) into r;
  return r;
end $$;

-- The original call is the Aptitude board.
create or replace function public.leaderboard(p_scope text default 'college', p_limit int default 50)
returns json
language plpgsql security definer set search_path = '' as $$
begin
  return public.leaderboard(p_scope, p_limit, 'aptitude');
end $$;

-- Profiles ----------------------------------------------------------------

-- get_profile (0014) with the player's rating in every subject.
create or replace function public.get_profile(p_id uuid) returns json
language plpgsql stable security definer set search_path = '' as $$
declare
  viewer uuid := auth.uid();
  p public.profiles;
  college_name text;
begin
  select * into p from public.profiles where id = p_id and deleted_at is null;
  if not found then
    return null;
  end if;
  select name into college_name from public.colleges where id = p.college_id;

  return json_build_object(
    'id',           p.id,
    'name',         p.display_name,
    'college',      college_name,
    'grad_year',    p.grad_year,
    'rating',       p.rating,
    'games_played', p.games_played,
    'wins',         p.wins,
    'streak',       case when p.last_played_on >= public._today() - 1 then p.streak_current else 0 end,
    'streak_best',  p.streak_best,
    'is_bot',       p.is_bot,
    'tagline',      p.tagline,
    'is_me',        p.id = viewer,
    'joined',       p.created_at,
    'subjects',     public._subjects_json(p.id),
    'college_rank', case when p.college_id is null or p.last_played_on is null or p.is_bot then null else
                      (select 1 + count(*) from public.profiles x
                        where x.college_id = p.college_id and x.rating > p.rating
                          and not x.is_bot and x.deleted_at is null and x.last_played_on is not null) end,
    -- The last 10 finished duels, newest first: W, L or D.
    'recent',       coalesce((select json_agg(f.result order by f.at desc) from (
                      select case
                               when a.score > b.score or (a.score = b.score and a.total_ms < b.total_ms) then 'W'
                               when a.score = b.score and a.total_ms = b.total_ms then 'D'
                               else 'L'
                             end as result,
                             a.finished_at as at
                        from public.duel_players a
                        join public.duel_players b on b.duel_id = a.duel_id and b.id <> a.id
                       where a.user_id = p.id and not a.is_replay
                         and a.finished_at is not null and b.finished_at is not null
                       order by a.finished_at desc
                       limit 10) f), '[]'::json),
    -- The viewer's own record against this player.
    'vs_me',        case when viewer is null or viewer = p.id then null else (
                      select json_build_object(
                               'played', count(*),
                               'wins',   count(*) filter (where a.score > b.score or (a.score = b.score and a.total_ms < b.total_ms)),
                               'losses', count(*) filter (where b.score > a.score or (a.score = b.score and b.total_ms < a.total_ms)))
                        from public.duel_players a
                        join public.duel_players b on b.duel_id = a.duel_id and b.id <> a.id
                       where a.user_id = viewer and b.user_id = p.id
                         and a.finished_at is not null and b.finished_at is not null) end
  );
end $$;

-- Who can call what ----------------------------------------------------------

revoke execute on function public._week_delta(uuid, timestamptz, text), public._subjects_json(uuid)
  from public, anon, authenticated;
revoke execute on function public.leaderboard(text, int, text) from public, anon;
grant execute on function public.leaderboard(text, int, text) to authenticated;

notify pgrst, 'reload schema';
