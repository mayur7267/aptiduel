-- =====================================================================
-- Apticks · 0011_challenge_owner_view
-- When the challenger opens their own challenge link, the page shows
-- their side of it (waiting for friends, who has played, who won)
-- instead of "X challenged you". challenge_status answers only the
-- challenger, and returns null for anyone else.
-- Safe to run more than once.
-- =====================================================================

create or replace function public.challenge_status(p_code text) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  d public.duels;
  me public.duel_players;
begin
  select * into d from public.duels
   where code = upper(btrim(p_code)) and parent_id is null and mode = 'challenge';
  if not found then
    return null;
  end if;
  select * into me from public.duel_players
   where duel_id = d.id and seat = 1 and user_id = uid and not is_replay;
  if not found then
    return null; -- not the challenger
  end if;

  -- Each friend's run: the first one plays in the original duel, later
  -- ones in their own copy against the challenger's recorded run.
  return json_build_object(
    'duel_id', d.id,
    'code',    d.code,
    'open',    d.expires_at > now(),
    'me',      json_build_object(
                 'name',     (select display_name from public.profiles where id = uid),
                 'finished', me.finished_at is not null,
                 'score',    me.score,
                 'correct',  me.correct,
                 'total_ms', me.total_ms),
    'friends', coalesce((
                 select json_agg(json_build_object(
                          'duel_id',  xd.id,
                          'name',     pr.display_name,
                          'college',  c.name,
                          'finished', f.finished_at is not null,
                          'score',    f.score,
                          'correct',  f.correct,
                          'total_ms', f.total_ms)
                        order by f.started_at)
                   from public.duels xd
                   join public.duel_players f on f.duel_id = xd.id and f.seat = 2
                   join public.profiles pr on pr.id = f.user_id
                   left join public.colleges c on c.id = pr.college_id
                  where xd.id = d.id or xd.parent_id = d.id), '[]'::json)
  );
end $$;

revoke execute on function public.challenge_status(text) from public, anon;
grant execute on function public.challenge_status(text) to authenticated;
