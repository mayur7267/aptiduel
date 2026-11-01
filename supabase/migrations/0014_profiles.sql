-- =====================================================================
-- Apticks · 0014_profiles
-- Public player profiles. Anyone can open a player's profile (from the
-- leaderboard, a result or a friend duel): name, college, rating, stats,
-- recent form, and, for a signed-in viewer, their record against that
-- player. Leaderboard rows and duel players now carry the player's id so
-- the apps can link to it. Run after 0013. Safe to run more than once.
-- =====================================================================

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

-- Duel players now carry their id, for linking to their profile.
create or replace function public._player_json(p public.duel_players) returns json
language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'id',            p.user_id,
    'seat',          p.seat,
    'name',          pr.display_name,
    'rating',        pr.rating,
    'college',       c.name,
    'is_bot',        pr.is_bot,
    'tagline',       pr.tagline,
    'score',         p.score,
    'correct',       p.correct,
    'total_ms',      p.total_ms,
    'answered',      p.current_q,
    'finished',      p.finished_at is not null,
    'is_replay',     p.is_replay,
    'rating_before', p.rating_before,
    'rating_after',  p.rating_after
  )
  from public.profiles pr
  left join public.colleges c on c.id = pr.college_id
  where pr.id = p.user_id
$$;

-- Leaderboard rows now carry the player's id, for linking to their profile.
create or replace function public.leaderboard(p_scope text default 'college', p_limit int default 50)
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
  select college_id into my_college from public.profiles where id = uid;

  -- Rank everyone, but only work out the weekly change for rows shown.
  with ranked as (
    select pr.id, pr.display_name, pr.rating, pr.grad_year, c.name as college,
           rank() over (order by pr.rating desc) as rnk
      from public.profiles pr
      left join public.colleges c on c.id = pr.college_id
     where pr.last_played_on is not null
       and not pr.is_bot
       and pr.deleted_at is null
       and (p_scope = 'india' or pr.college_id = my_college)
  ), shown as (
    select * from ranked order by rnk, display_name limit least(greatest(p_limit, 1), 100)
  )
  select json_build_object(
           'scope',   p_scope,
           'college', (select name from public.colleges where id = my_college),
           'players', (select count(*) from ranked),
           'rows',    coalesce((select json_agg(json_build_object(
                                         'id',         x.id,
                                         'rank',       x.rnk,
                                         'name',       x.display_name,
                                         'rating',     x.rating,
                                         'college',    x.college,
                                         'grad_year',  x.grad_year,
                                         'week_delta', public._week_delta(x.id, week_start),
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
                                'week_delta', public._week_delta(x.id, week_start),
                                'is_me',      true)
                         from ranked x where x.id = uid)
         ) into r;
  return r;
end $$;

revoke all on function public.get_profile(uuid) from public;
grant execute on function public.get_profile(uuid) to anon, authenticated;
