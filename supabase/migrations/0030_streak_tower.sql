-- =====================================================================
-- Apticks · 0030_streak_tower
-- The Streak Tower page: your streak, your best, the days you played
-- (the last 120, India time) and the longest live streaks in your college.
-- Streaks themselves are unchanged: one finished duel a day keeps them
-- going (_touch_streak in 0001_init.sql).
-- =====================================================================

-- Not stable: _require_player may create your profile row.
create or replace function public.my_streak()
returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  p public.profiles%rowtype;
begin
  select * into p from public.profiles where id = uid;
  return json_build_object(
    -- A streak is alive while you played today or yesterday.
    'streak',       case when p.last_played_on >= public._today() - 1 then p.streak_current else 0 end,
    'best',         p.streak_best,
    'played_today', coalesce(p.last_played_on = public._today(), false),
    'days',         coalesce((
                      select json_agg(d order by d)
                        from (select distinct (dp.finished_at at time zone 'Asia/Kolkata')::date as d
                                from public.duel_players dp
                               where dp.user_id = uid
                                 and not dp.is_replay
                                 and dp.finished_at is not null
                                 and dp.finished_at > now() - interval '120 days') x
                    ), '[]'::json),
    'college',      (select name from public.colleges where id = p.college_id),
    'college_top',  coalesce((
                      select json_agg(json_build_object('name', t.name, 'streak', t.streak, 'is_me', t.id = uid)
                                      order by t.streak desc, t.name)
                        from (select pr.id,
                                     split_part(btrim(pr.display_name), ' ', 1)
                                       || coalesce(' ' || left(nullif(split_part(btrim(pr.display_name), ' ', 2), ''), 1) || '.', '') as name,
                                     pr.streak_current as streak
                                from public.profiles pr
                               where p.college_id is not null
                                 and pr.college_id = p.college_id
                                 and not pr.is_bot
                                 and pr.deleted_at is null
                                 and pr.streak_current > 0
                                 and pr.last_played_on >= public._today() - 1
                               order by pr.streak_current desc, pr.display_name
                               limit 5) t
                    ), '[]'::json)
  );
end $$;

revoke all on function public.my_streak() from public, anon;
grant execute on function public.my_streak() to authenticated;
