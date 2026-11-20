-- =====================================================================
-- Apticks · 0023_room_subjects
-- Friend duels in a subject. A live room is Aptitude or Coding: the host
-- picks it in the lobby until the friend joins (it starts on the subject
-- open on their Quick Match card), and the invite, the link preview and
-- both lobbies say which. A rematch keeps the subject. The subject lives
-- on the duel's set (duel_sets.subject, 0022), as for quick matches.
--
-- Older apps (iOS 1.0 and 1.1) can't show code. They call
-- join_room(p_code) and join_challenge(p_code), and are kept out of
-- Coding duels with a clear message; newer apps and the website call
-- join_room(p_code, p_client) and join_challenge(p_code, p_client), where
-- p_client 2 means "shows code".
-- Safe to run more than once.
-- =====================================================================

-- What a duel is about.
create or replace function public._set_subject(p_set_id bigint) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce((select subject from public.duel_sets where id = p_set_id), 'aptitude')
$$;

-- Keeps apps that can't show code out of Coding duels.
create or replace function public._check_client(p_set_id bigint, p_client int) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if coalesce(p_client, 1) < 2 and public._set_subject(p_set_id) = 'coding' then
    raise exception 'This is a Coding duel, and this version of Apticks can''t show code. Update the app, or open the link in your browser.';
  end if;
end $$;

-- Opening a room ----------------------------------------------------------

-- create_room() as before (Aptitude), in a chosen subject.
create or replace function public.create_room(p_subject text) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_member();
  d public.duels;
begin
  if p_subject is null or p_subject not in ('aptitude', 'coding') then
    raise exception 'Unknown subject.';
  end if;
  if (select count(*) from public.duels
       where created_by = uid and parent_id is null
         and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'Too many new duels. Try again in a few minutes.';
  end if;

  insert into public.duels (code, mode, set_id, created_by)
  values (public._new_code(), 'live', public._new_set(array[uid], p_subject), uid)
  returning * into d;
  insert into public.duel_players (duel_id, user_id, seat, seen_at) values (d.id, uid, 1, now());
  return json_build_object('duel_id', d.id, 'code', d.code, 'subject', p_subject);
end $$;

-- The host switches the subject while waiting. Once the friend is in,
-- it's set.
create or replace function public.set_room_subject(p_duel_id uuid, p_subject text) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_member();
  d public.duels;
begin
  if p_subject is null or p_subject not in ('aptitude', 'coding') then
    raise exception 'Unknown subject.';
  end if;
  select * into d from public.duels where id = p_duel_id for update;
  if not found or d.mode <> 'live' or not exists (
       select 1 from public.duel_players where duel_id = d.id and user_id = uid and seat = 1) then
    raise exception 'Only the player who opened the room can change it.';
  end if;
  if d.starts_at is not null or d.expires_at <= now()
     or exists (select 1 from public.duel_players where duel_id = d.id and seat = 2) then
    raise exception 'Your friend is already in, so the subject is set.';
  end if;

  if public._set_subject(d.set_id) <> p_subject then
    update public.duels set set_id = public._new_set(array[uid], p_subject) where id = d.id;
  end if;
  return json_build_object('subject', p_subject);
end $$;

-- Joining -----------------------------------------------------------------

-- join_challenge (0010) for both kinds of app.
create or replace function public._join_challenge(p_code text, p_client int) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  d public.duels;
  src public.duel_players;
  new_duel uuid;
  new_player uuid;
begin
  select * into d from public.duels
   where code = upper(btrim(p_code)) and parent_id is null and mode = 'challenge'
   for update;
  if not found then
    raise exception 'Challenge not found.';
  end if;
  perform public._check_client(d.set_id, p_client);

  if exists (select 1 from public.duel_players where duel_id = d.id and user_id = uid) then
    return json_build_object('duel_id', d.id);
  end if;

  select x.id into new_duel
    from public.duels x
    join public.duel_players xp on xp.duel_id = x.id and xp.user_id = uid
   where x.parent_id = d.id;
  if found then
    return json_build_object('duel_id', new_duel);
  end if;

  if d.expires_at <= now() then
    raise exception 'This challenge has expired.';
  end if;

  if not exists (select 1 from public.duel_players where duel_id = d.id and seat = 2) then
    insert into public.duel_players (duel_id, user_id, seat) values (d.id, uid, 2);
    return json_build_object('duel_id', d.id);
  end if;

  select * into src from public.duel_players where duel_id = d.id and seat = 1;
  if src.finished_at is null then
    raise exception 'Your friend hasn''t played this challenge yet. Try again once they have.';
  end if;

  insert into public.duels (code, mode, set_id, created_by, parent_id, expires_at, company)
  values (public._new_code(), 'challenge', d.set_id, src.user_id, d.id, d.expires_at, d.company)
  returning id into new_duel;

  insert into public.duel_players
    (duel_id, user_id, seat, is_replay, current_q, score, correct, total_ms, started_at, finished_at)
  values
    (new_duel, src.user_id, 1, true, src.current_q, src.score, src.correct, src.total_ms,
     src.started_at, src.finished_at)
  returning id into new_player;

  insert into public.answers
    (player_id, q_index, question_id, sent_at, answered_at, chosen_idx, is_correct, points)
  select new_player, q_index, question_id, sent_at, answered_at, chosen_idx, is_correct, points
    from public.answers where player_id = src.id;

  insert into public.duel_players (duel_id, user_id, seat) values (new_duel, uid, 2);
  return json_build_object('duel_id', new_duel);
end $$;

create or replace function public.join_challenge(p_code text) returns json
language plpgsql security definer set search_path = '' as $$
begin
  return public._join_challenge(p_code, 1);
end $$;

create or replace function public.join_challenge(p_code text, p_client int) returns json
language plpgsql security definer set search_path = '' as $$
begin
  return public._join_challenge(p_code, p_client);
end $$;

-- join_room (0019) for both kinds of app. When the friend joins, the
-- questions are picked again for the two of them, in the room's subject.
create or replace function public._join_room(p_code text, p_client int) returns json
language plpgsql security definer set search_path = '' as $$
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
    return (public._join_challenge(p_code, p_client)::jsonb || '{"mode": "challenge"}')::json;
  end if;
  perform public._check_client(d.set_id, p_client);

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
      update public.duels set set_id = public._new_set(array[d.created_by, uid], public._set_subject(d.set_id))
       where id = d.id;
    end if;
  end if;
  perform public._live_tick(d.id);
  return json_build_object('duel_id', d.id, 'mode', 'live');
end $$;

create or replace function public.join_room(p_code text) returns json
language plpgsql security definer set search_path = '' as $$
begin
  return public._join_room(p_code, 1);
end $$;

create or replace function public.join_room(p_code text, p_client int) returns json
language plpgsql security definer set search_path = '' as $$
begin
  return public._join_room(p_code, p_client);
end $$;

-- The lobby and the rematch -------------------------------------------------

-- live_state (0013), saying the subject.
create or replace function public.live_state(p_duel_id uuid) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  d public.duels;
  me public.duel_players;
  opp public.duel_players;
begin
  select * into me from public.duel_players where duel_id = p_duel_id and user_id = uid;
  if not found then
    raise exception 'You are not in this duel.';
  end if;
  update public.duel_players set seen_at = now() where id = me.id;
  perform public._live_tick(p_duel_id);

  select * into d from public.duels where id = p_duel_id;
  select * into me from public.duel_players where id = me.id;
  select * into opp from public.duel_players where duel_id = p_duel_id and user_id <> uid;

  return json_build_object(
    'id',           d.id,
    'code',         d.code,
    'status',       case
                      when d.mode <> 'live' then 'async'
                      when d.status = 'complete' then 'done'
                      when d.starts_at is null and d.expires_at <= now() then 'closed'
                      when d.starts_at is null then 'waiting'
                      when now() < d.starts_at then 'starting'
                      else 'playing'
                    end,
    'is_host',      me.seat = 1,
    'now_ms',       floor(extract(epoch from now()) * 1000)::bigint,
    'starts_at_ms', floor(extract(epoch from d.starts_at) * 1000)::bigint,
    'me',           public._live_player_json(me),
    'opponent',     case when opp.id is null then null else public._live_player_json(opp) end,
    'rematch_id',   d.rematch_id,
    'subject',      public._set_subject(d.set_id)
  );
end $$;

-- live_rematch (0019), in the same subject.
create or replace function public.live_rematch(p_duel_id uuid) returns json
language plpgsql security definer set search_path = '' as $$
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
  values (public._new_code(), 'live', public._new_set(array[uid, other], public._set_subject(d.set_id)), uid)
  returning * into fresh;
  insert into public.duel_players (duel_id, user_id, seat, seen_at)
  values (fresh.id, uid, 1, now()), (fresh.id, other, 2, null);
  update public.duels set rematch_id = fresh.id where id = d.id;
  return json_build_object('duel_id', fresh.id, 'code', fresh.code);
end $$;

-- A link's public info (0013), saying the subject, so the invite and the
-- link preview can.
create or replace function public.get_challenge(p_code text) returns json
language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'code',                d.code,
    'open',                d.expires_at > now(),
    'live',                d.mode = 'live',
    'started',             d.starts_at is not null,
    'full',                exists (select 1 from public.duel_players x where x.duel_id = d.id and x.seat = 2),
    'my_seat',             (select x.seat from public.duel_players x where x.duel_id = d.id and x.user_id = auth.uid()),
    'subject',             public._set_subject(d.set_id),
    'challenger',          json_build_object(
                             'name',      pr.display_name,
                             'rating',    pr.rating,
                             'college',   c.name,
                             'grad_year', pr.grad_year),
    'challenger_finished', p1.finished_at is not null,
    'score',               p1.score,
    'correct',             p1.correct,
    'total_ms',            p1.total_ms,
    'accepted_count',      (select count(*) from public.duel_players x
                              join public.duels xd on xd.id = x.duel_id
                             where x.seat = 2 and (xd.id = d.id or xd.parent_id = d.id))
  )
  from public.duels d
  join public.duel_players p1 on p1.duel_id = d.id and p1.seat = 1
  join public.profiles pr on pr.id = p1.user_id
  left join public.colleges c on c.id = pr.college_id
  where d.code = upper(btrim(p_code)) and d.parent_id is null and d.mode in ('challenge', 'live')
    and pr.deleted_at is null
$$;

-- Who can call what ----------------------------------------------------------

revoke execute on function public._set_subject(bigint), public._check_client(bigint, int),
  public._join_challenge(text, int), public._join_room(text, int)
  from public, anon, authenticated;
revoke execute on function public.create_room(text), public.set_room_subject(uuid, text),
  public.join_challenge(text, int), public.join_room(text, int)
  from public, anon;
grant execute on function public.create_room(text), public.set_room_subject(uuid, text),
  public.join_challenge(text, int), public.join_room(text, int)
  to authenticated;
grant execute on function public.get_challenge(text) to anon, authenticated;

notify pgrst, 'reload schema';
