-- =====================================================================
-- Apticks · 0019_fewer_repeats
-- Smarter question picking, so players rarely see a question twice and,
-- when they do, the repeat is useful.
--
-- 1. Questions nobody in the duel has answered come first. Live rooms and
--    rematches now look at both players' history, not just the host's.
-- 2. When a player has seen everything in a section, repeats start with
--    the questions they got wrong, then the ones seen longest ago.
--
-- Challenge links and quick matches still replay the set the first player
-- had, because both players must get the same questions.
-- =====================================================================

-- p_n questions from one section, best first for these players.
-- p_visual: true for picture questions only, false for text only, null for either.
create or replace function public._pick(p_users uuid[], p_section text, p_n int, p_visual boolean default null, p_company text default null)
returns setof bigint
language sql
volatile
security definer
set search_path = ''
as $$
  with history as (
    select a.question_id,
           max(coalesce(a.answered_at, a.sent_at)) as last_seen,
           bool_or(a.is_correct is not true) as missed
      from public.answers a
      join public.duel_players dp on dp.id = a.player_id
     where dp.user_id = any(p_users) and not dp.is_replay
     group by a.question_id
  )
  select q.id
    from public.questions q
    left join history h on h.question_id = q.id
   where q.status = 'active'
     and q.section = p_section
     and (p_visual is null or (q.option_figures is not null) = p_visual)
     and (p_company is null or p_company = any(q.company_tags))
   order by h.question_id is not null, h.missed desc, h.last_seen, random()
   limit p_n
$$;
revoke execute on function public._pick(uuid[], text, int, boolean, text) from public, anon, authenticated;

-- A new set of five for these players: 2 quant, 2 reasoning (one with
-- pictures when there is one), 1 verbal.
create or replace function public._new_set(p_users uuid[])
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  ids bigint[];
  sid bigint;
  pic bigint[];
begin
  select array_agg(id) into pic from public._pick(p_users, 'reasoning', 1, true) id;
  select array_agg(id order by random()) into ids from (
    select public._pick(p_users, 'quant', 2) as id
    union all select unnest(pic)
    union all select public._pick(p_users, 'reasoning', 2 - coalesce(array_length(pic, 1), 0), false)
    union all select public._pick(p_users, 'verbal', 1)
  ) picked;
  if coalesce(array_length(ids, 1), 0) < 5 then
    raise exception 'The question bank is empty. Load the seed first.';
  end if;
  insert into public.duel_sets (question_ids) values (ids) returning id into sid;
  return sid;
end $$;
revoke execute on function public._new_set(uuid[]) from public, anon, authenticated;

-- The caller's own set, as before.
create or replace function public._new_set()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
begin
  return public._new_set(array[auth.uid()]);
end $$;

create or replace function public._company_set(p_company text)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  ids bigint[];
  sid bigint;
  me uuid[] := array[auth.uid()];
begin
  select array_agg(id order by random()) into ids from (
    select public._pick(me, 'quant', 2, null, p_company) as id
    union all select public._pick(me, 'reasoning', 2, null, p_company)
    union all select public._pick(me, 'verbal', 1, null, p_company)
  ) picked;
  if coalesce(array_length(ids, 1), 0) < 5 then
    raise exception 'There aren''t enough % questions yet.', p_company;
  end if;
  insert into public.duel_sets (question_ids) values (ids) returning id into sid;
  return sid;
end $$;

-- When a friend takes the second seat in a live room before anyone has
-- answered, pick the set again for both of them.
create or replace function public.join_room(p_code text)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public._require_member();
  d public.duels;
begin
  select * into d from public.duels
   where code = upper(btrim(p_code)) and parent_id is null and mode in ('live', 'challenge')
   for update;
  if not found then
    raise exception 'Duel not found.';
  end if;
  if d.mode = 'challenge' then
    return (public.join_challenge(p_code)::jsonb || '{"mode": "challenge"}')::json;
  end if;

  if exists (select 1 from public.duel_players where duel_id = d.id and user_id = uid) then
    update public.duel_players set seen_at = now() where duel_id = d.id and user_id = uid;
  else
    if d.expires_at <= now() then
      raise exception 'This duel has closed. Ask your friend for a new link.';
    end if;
    if exists (select 1 from public.duel_players where duel_id = d.id and seat = 2) then
      raise exception 'This duel already has two players.';
    end if;
    insert into public.duel_players (duel_id, user_id, seat, seen_at) values (d.id, uid, 2, now());
    if not exists (select 1 from public.answers a join public.duel_players dp on dp.id = a.player_id where dp.duel_id = d.id) then
      update public.duels set set_id = public._new_set(array[d.created_by, uid]) where id = d.id;
    end if;
  end if;
  perform public._live_tick(d.id);
  return json_build_object('duel_id', d.id, 'mode', 'live');
end $$;

-- A rematch looks at both players' history.
create or replace function public.live_rematch(p_duel_id uuid)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public._require_member();
  d public.duels;
  other uuid;
  fresh public.duels;
begin
  select * into d from public.duels where id = p_duel_id for update;
  if not exists (select 1 from public.duel_players where duel_id = p_duel_id and user_id = uid) then
    raise exception 'You are not in this duel.';
  end if;
  if d.mode <> 'live' or d.status <> 'complete' then
    raise exception 'Finish the duel first.';
  end if;
  if d.rematch_id is not null then
    return json_build_object('duel_id', d.rematch_id, 'code', (select code from public.duels where id = d.rematch_id));
  end if;
  select user_id into other from public.duel_players where duel_id = p_duel_id and user_id <> uid;
  if exists (select 1 from public.profiles where id = other and deleted_at is not null) then
    raise exception 'Your friend has left Apticks.';
  end if;

  insert into public.duels (code, mode, set_id, created_by)
  values (public._new_code(), 'live', public._new_set(array[uid, other]), uid)
  returning * into fresh;
  insert into public.duel_players (duel_id, user_id, seat, seen_at)
  values (fresh.id, uid, 1, now()), (fresh.id, other, 2, null);
  update public.duels set rematch_id = fresh.id where id = d.id;
  return json_build_object('duel_id', fresh.id, 'code', fresh.code);
end $$;
