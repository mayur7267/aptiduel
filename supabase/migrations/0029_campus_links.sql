-- =====================================================================
-- Apticks · 0029_campus_links
-- Campus links: playapticks.in/join/<college id>-<name> puts a student
-- straight onto their college's board, so a class shared in one WhatsApp
-- group lands on the same leaderboard on day one.
--
-- 1. college_card(id): the public face of one college for the join page
--    and its link preview: name, place, how many play, the top three.
-- 2. join_college(id): sets your college. A newcomer who joins this way
--    is noted as arriving through a campus link.
-- 3. Arrivals and share taps can say 'campus'.
-- =====================================================================

alter table public.arrivals drop constraint if exists arrivals_via_check;
alter table public.arrivals add constraint arrivals_via_check check (via in ('daily', 'story', 'campus'));

alter table public.share_events drop constraint if exists share_events_kind_check;
alter table public.share_events add constraint share_events_kind_check check (kind in ('daily', 'story', 'challenge', 'campus'));

-- One college, for anyone (the join page is read before anyone signs in).
-- Players show as first name and initial, as on shared cards.
create or replace function public.college_card(p_id int)
returns json
language sql stable security definer set search_path = '' as $$
  with players as (
    select btrim(pr.display_name) as n, pr.rating
      from public.profiles pr
     where pr.college_id = p_id
       and not pr.is_bot
       and pr.deleted_at is null
       and pr.last_played_on is not null
  ), top as (
    select split_part(n, ' ', 1)
           || coalesce(' ' || left(nullif(split_part(n, ' ', 2), ''), 1) || '.', '') as name,
           rating
      from players
     order by rating desc, n
     limit 3
  )
  select json_build_object(
           'id',      c.id,
           'name',    c.name,
           'city',    c.city,
           'country', c.country,
           'players', (select count(*) from players),
           'top',     coalesce((select json_agg(json_build_object('name', t.name, 'rating', t.rating)
                                                order by t.rating desc) from top t), '[]'::json))
    from public.colleges c
   where c.id = p_id;
$$;

revoke all on function public.college_card(int) from public;
grant execute on function public.college_card(int) to anon, authenticated;

-- Join a college from its campus link. Changing college is allowed (the
-- page asks first when you already have one).
create or replace function public.join_college(p_id int)
returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
begin
  if not exists (select 1 from public.colleges where id = p_id) then
    raise exception 'Unknown college.';
  end if;
  update public.profiles set college_id = p_id where id = uid;
  -- Only a newcomer's first way in, as note_arrival does.
  if not exists (select 1 from public.duel_players where user_id = uid) then
    insert into public.arrivals (user_id, via, code)
    values (uid, 'campus', p_id::text)
    on conflict (user_id) do update set via = 'campus', code = excluded.code;
  end if;
  return public.get_me();
end $$;

revoke all on function public.join_college(int) from public, anon;
grant execute on function public.join_college(int) to authenticated;
