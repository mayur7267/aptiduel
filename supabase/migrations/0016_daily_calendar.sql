-- =====================================================================
-- Apticks · 0016_daily_calendar
-- The days you finished the Daily Challenge, for the calendar behind the
-- Daily card on home: IST dates, oldest first, over the last 400 days.
-- The week of bubbles on the card (get_me's daily_week) counts the same
-- way, so the two always agree.
-- Run after 0015. Safe to run more than once.
-- =====================================================================

create or replace function public.daily_days() returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
begin
  return coalesce((
    select json_agg(day order by day)
      from (select distinct (dp.finished_at at time zone 'Asia/Kolkata')::date as day
              from public.duel_players dp
              join public.duels d on d.id = dp.duel_id
             where dp.user_id = uid and d.mode = 'daily' and dp.finished_at is not null
               and dp.finished_at > now() - interval '400 days') days
  ), '[]'::json);
end $$;

revoke all on function public.daily_days() from public, anon;
grant execute on function public.daily_days() to authenticated;
