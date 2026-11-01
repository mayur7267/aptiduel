-- =====================================================================
-- Apticks · 0013_live_duels
-- Live friend duels. A player opens a room and shares its link, and both
-- wait in a lobby until the friend joins. Then a short countdown, and a
-- race: the same 5 questions, starting at the same moment, each player at
-- their own pace, watching the other's progress. More points wins (100 a
-- right answer plus up to 50 for speed); total time breaks a tie.
--
-- Friend duels need a saved (email) account on both sides. Quick
-- matches, the daily challenge and company practice stay open to guests.
--
-- If the friend doesn't come, either player can press "Play now": the
-- room becomes an ordinary challenge, and the other side races the
-- recorded run whenever they open the link, so links never go dead.
--
-- Questions and answers go through next_question and submit_answer as in
-- every other duel. The players' screens call live_state about once a
-- second, which marks them as present, starts the countdown once both are
-- in the lobby, and forfeits the rest of a run whose player has been gone
-- for 45 s, so nobody is left waiting.
-- Safe to run more than once.
-- =====================================================================

alter table public.duels drop constraint if exists duels_mode_check;
alter table public.duels add constraint duels_mode_check
  check (mode in ('challenge', 'quick', 'daily', 'live'));

-- When a live duel starts (the first question opens for both). Null
-- until both players are in the lobby.
alter table public.duels add column if not exists starts_at timestamptz;
-- A rematch room made from this duel, so the other player can join it.
alter table public.duels add column if not exists rematch_id uuid references public.duels (id) on delete set null;
-- When each player's screen last checked in.
alter table public.duel_players add column if not exists seen_at timestamptz;

-- The signed-in player, who must have a saved account (not a guest).
create or replace function public._require_member() returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
begin
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Sign in to duel friends.';
  end if;
  return uid;
end $$;

create or replace function public.next_question(p_duel_id uuid) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  p public.duel_players;
  qid bigint;
  q public.questions;
  a public.answers;
  duel public.duels;
  elapsed_ms int;
begin
  -- A live duel starts for both players at once, when the countdown ends.
  select * into duel from public.duels where id = p_duel_id;
  if duel.mode = 'live' and (duel.starts_at is null or now() < duel.starts_at) then
    raise exception 'The duel hasn''t started yet.';
  end if;

  select * into p from public.duel_players
   where duel_id = p_duel_id and user_id = uid
   for update;
  if not found then
    raise exception 'You are not in this duel.';
  end if;
  if p.finished_at is not null then
    return json_build_object('done', true, 'score', p.score);
  end if;

  select s.question_ids[p.current_q + 1] into qid
    from public.duels d join public.duel_sets s on s.id = d.set_id
   where d.id = p_duel_id;
  select * into q from public.questions where id = qid;

  -- In a live duel the first question opened for both at the start.
  insert into public.answers (player_id, q_index, question_id, sent_at)
  values (p.id, p.current_q, qid,
          case when duel.mode = 'live' and p.current_q = 0 then duel.starts_at else now() end)
  on conflict (player_id, q_index) do nothing;
  select * into a from public.answers where player_id = p.id and q_index = p.current_q;

  elapsed_ms := (extract(epoch from (now() - a.sent_at)) * 1000)::int;
  return json_build_object(
    'done',           false,
    'q_index',        p.current_q,
    'total',          5,
    'section',        q.section,
    'topic',          q.topic,
    'companies',      q.company_tags,
    'difficulty',     q.difficulty,
    'body',           q.body,
    'figure',         q.figure,
    'options',        q.options,
    'option_figures', q.option_figures,
    'time_limit_ms',  q.time_limit_s * 1000,
    'remaining_ms',   greatest(0, q.time_limit_s * 1000 - elapsed_ms),
    'score',          p.score
  );
end $$;

-- Two players move each other's rating at most once a day, now counting
-- live duels as well as challenges.
create or replace function public._settle_duel(p_duel_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  d public.duels;
  p1 public.duel_players;
  p2 public.duel_players;
  r1 int; g1 int;
  r2 int; g2 int;
  s1 numeric;  -- seat 1's result: 1 win, 0.5 draw, 0 loss
  e1 numeric;  -- seat 1's expected result
  n1 int; n2 int;
begin
  select * into d from public.duels where id = p_duel_id;
  select * into p1 from public.duel_players where duel_id = p_duel_id and seat = 1 for update;
  select * into p2 from public.duel_players where duel_id = p_duel_id and seat = 2 for update;
  if p1.id is null or p2.id is null
     or p1.finished_at is null or p2.finished_at is null
     or p2.rating_after is not null then
    return;
  end if;

  select rating, games_played into r1, g1 from public.profiles where id = p1.user_id for update;
  select rating, games_played into r2, g2 from public.profiles where id = p2.user_id for update;

  if p1.score > p2.score or (p1.score = p2.score and p1.total_ms < p2.total_ms) then
    s1 := 1;
  elsif p1.score = p2.score and p1.total_ms = p2.total_ms then
    s1 := 0.5;
  else
    s1 := 0;
  end if;

  e1 := 1 / (1 + power(10::numeric, (r2 - r1) / 400.0));
  -- New players move faster (K = 40 for their first 10 games, then 24).
  n1 := greatest(100, r1 + round(case when g1 < 10 then 40 else 24 end * (s1 - e1))::int);
  n2 := greatest(100, r2 + round(case when g2 < 10 then 40 else 24 end * (e1 - s1))::int);

  if d.mode in ('challenge', 'live') and not p1.is_replay and exists (
       select 1
         from public.duel_players a
         join public.duel_players b on b.duel_id = a.duel_id and b.user_id <> a.user_id
         join public.duels x on x.id = a.duel_id
        where x.mode in ('challenge', 'live') and x.id <> p_duel_id
          and a.user_id in (p1.user_id, p2.user_id)
          and b.user_id in (p1.user_id, p2.user_id)
          and not a.is_replay and not b.is_replay
          and a.rating_after is distinct from a.rating_before
          and a.finished_at > now() - interval '1 day') then
    n1 := r1;
    n2 := r2;
  end if;

  if p1.is_replay then
    n1 := r1;
  else
    update public.profiles
       set rating = n1, games_played = games_played + 1, wins = wins + (s1 = 1)::int
     where id = p1.user_id;
  end if;

  update public.profiles
     set rating = n2, games_played = games_played + 1, wins = wins + (s1 = 0)::int
   where id = p2.user_id;

  update public.duel_players set rating_before = r1, rating_after = n1 where id = p1.id;
  update public.duel_players set rating_before = r2, rating_after = n2 where id = p2.id;
  update public.duels set status = 'complete' where id = p_duel_id;
end $$;

-- Moves a live duel on: starts the countdown (5 s: see each other, then
-- 3-2-1) once both players are in the lobby, and forfeits the rest of a
-- run whose player has been gone for 45 s.
create or replace function public._live_tick(p_duel_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  d public.duels;
  pl uuid;
begin
  select * into d from public.duels where id = p_duel_id for update;
  if not found or d.mode <> 'live' or d.status <> 'open' then
    return;
  end if;

  if d.starts_at is null then
    if d.expires_at > now() and (select count(*) from public.duel_players
                                   where duel_id = d.id and seen_at > now() - interval '15 seconds') = 2 then
      update public.duels set starts_at = now() + interval '5 seconds' where id = d.id;
    end if;
    return;
  end if;

  for pl in select dp.id from public.duel_players dp
             where dp.duel_id = d.id and dp.finished_at is null
               and now() > d.starts_at + interval '45 seconds'
               and coalesce(dp.seen_at, d.starts_at) < now() - interval '45 seconds' loop
    perform public._forfeit_run(pl);
  end loop;
end $$;

-- One player's side of a live duel. The race is open, so scores and
-- right/wrong marks show as they happen.
create or replace function public._live_player_json(p public.duel_players) returns json
language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'id',       p.user_id,
    'seat',     p.seat,
    'name',     pr.display_name,
    'rating',   pr.rating,
    'college',  c.name,
    'present',  coalesce(p.seen_at > now() - interval '15 seconds', false),
    'answered', p.current_q,
    'correct',  p.correct,
    'score',    p.score,
    'finished', p.finished_at is not null,
    'marks',    coalesce((select json_agg(a.is_correct order by a.q_index)
                            from public.answers a
                           where a.player_id = p.id and a.answered_at is not null), '[]'::json)
  )
  from public.profiles pr
  left join public.colleges c on c.id = pr.college_id
  where pr.id = p.user_id
$$;

-- Open a live room. Returns its share code.
create or replace function public.create_room() returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_member();
  d public.duels;
begin
  if (select count(*) from public.duels
       where created_by = uid and parent_id is null
         and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'Too many new duels. Try again in a few minutes.';
  end if;

  insert into public.duels (code, mode, set_id, created_by)
  values (public._new_code(), 'live', public._new_set(), uid)
  returning * into d;
  insert into public.duel_players (duel_id, user_id, seat, seen_at) values (d.id, uid, 1, now());
  return json_build_object('duel_id', d.id, 'code', d.code);
end $$;

-- Join a friend's room from its link. A room that has already turned
-- into an ordinary challenge is joined as one (mode says which).
create or replace function public.join_room(p_code text) returns json
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
  end if;
  perform public._live_tick(d.id);
  return json_build_object('duel_id', d.id, 'mode', 'live');
end $$;

-- A live duel as of now: the lobby, the countdown and both players'
-- progress. Also marks the caller as present (see _live_tick).
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
    'rematch_id',   d.rematch_id
  );
end $$;

-- Stop waiting: the room becomes an ordinary challenge. The caller plays
-- now, and the other side races that run later.
create or replace function public.live_play_now(p_duel_id uuid) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  d public.duels;
begin
  select * into d from public.duels where id = p_duel_id for update;
  if not exists (select 1 from public.duel_players where duel_id = p_duel_id and user_id = uid) then
    raise exception 'You are not in this duel.';
  end if;
  if d.mode = 'live' then
    if d.starts_at is not null then
      raise exception 'This duel has already started.';
    end if;
    update public.duels set mode = 'challenge', expires_at = greatest(expires_at, now() + interval '7 days')
     where id = d.id;
  end if;
  return json_build_object('duel_id', d.id);
end $$;

-- The host closes a room nobody has started.
create or replace function public.live_cancel(p_duel_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
begin
  update public.duels d set expires_at = now()
   where d.id = p_duel_id and d.mode = 'live' and d.starts_at is null
     and exists (select 1 from public.duel_players dp
                  where dp.duel_id = d.id and dp.user_id = uid and dp.seat = 1);
end $$;

-- A new room with the same two players, linked from the finished duel so
-- the other player can join it from their result screen.
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
  values (public._new_code(), 'live', public._new_set(), uid)
  returning * into fresh;
  insert into public.duel_players (duel_id, user_id, seat, seen_at)
  values (fresh.id, uid, 1, now()), (fresh.id, other, 2, null);
  update public.duels set rematch_id = fresh.id where id = d.id;
  return json_build_object('duel_id', fresh.id, 'code', fresh.code);
end $$;

-- A link's public info now covers live rooms too: live says it's one,
-- and started or full says the friend can no longer join it. my_seat is
-- the caller's seat, if they're in it (always null for the share preview,
-- which has no session).
create or replace function public.get_challenge(p_code text) returns json
language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'code',                d.code,
    'open',                d.expires_at > now(),
    'live',                d.mode = 'live',
    'started',             d.starts_at is not null,
    'full',                exists (select 1 from public.duel_players x where x.duel_id = d.id and x.seat = 2),
    'my_seat',             (select x.seat from public.duel_players x where x.duel_id = d.id and x.user_id = auth.uid()),
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

revoke all on function public._require_member(), public._live_tick(uuid), public._live_player_json(public.duel_players)
  from public, anon, authenticated;
revoke all on function public.create_room(), public.join_room(text), public.live_state(uuid),
  public.live_play_now(uuid), public.live_cancel(uuid), public.live_rematch(uuid)
  from public, anon;
grant execute on function public.create_room(), public.join_room(text), public.live_state(uuid),
  public.live_play_now(uuid), public.live_cancel(uuid), public.live_rematch(uuid)
  to authenticated;
