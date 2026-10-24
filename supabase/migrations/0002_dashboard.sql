-- =====================================================================
-- AptiDuel · 0002_dashboard
-- Quick Match (against recorded runs of players near your rating),
-- the Daily Challenge, daily quests, leaderboards and account deletion.
-- =====================================================================


-- One shared set of 5 questions per day (IST).
create table if not exists public.daily_sets (
  day    date primary key,
  set_id bigint not null references public.duel_sets (id)
);
alter table public.daily_sets enable row level security;
revoke all on public.daily_sets from anon, authenticated;

create index if not exists duels_set_idx on public.duels (set_id);
create index if not exists duel_players_finished_idx on public.duel_players (finished_at)
  where finished_at is not null and not is_replay;


-- ---------------------------------------------------------------------
-- Challenge links only open challenge-mode duels (not quick or daily).
-- ---------------------------------------------------------------------

create or replace function public.get_challenge(p_code text) returns json
language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'code',                d.code,
    'open',                d.expires_at > now(),
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
  where d.code = upper(btrim(p_code)) and d.parent_id is null and d.mode = 'challenge'
$$;

create or replace function public.join_challenge(p_code text) returns json
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
    raise exception 'The challenger is still playing. Try again in a minute.';
  end if;

  insert into public.duels (code, mode, set_id, created_by, parent_id, expires_at)
  values (public._new_code(), 'challenge', d.set_id, src.user_id, d.id, d.expires_at)
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

-- Any finished run (quick, daily or someone else's challenge) can be
-- shared as a new challenge link carrying the player's own score.
create or replace function public.challenge_from_duel(p_duel_id uuid) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  me public.duel_players;
  d public.duels;
  made public.duels;
  new_player uuid;
begin
  select * into me from public.duel_players where duel_id = p_duel_id and user_id = uid;
  if not found then
    raise exception 'You are not in this duel.';
  end if;
  if me.finished_at is null then
    raise exception 'Finish the duel first.';
  end if;
  select * into d from public.duels where id = p_duel_id;

  if d.mode = 'challenge' and me.seat = 1 then
    return json_build_object('code', (select code from public.duels where id = coalesce(d.parent_id, d.id)));
  end if;

  select * into made from public.duels
   where parent_id is null and mode = 'challenge' and created_by = uid and set_id = d.set_id;
  if found then
    return json_build_object('code', made.code);
  end if;

  insert into public.duels (code, mode, set_id, created_by)
  values (public._new_code(), 'challenge', d.set_id, uid)
  returning * into made;

  insert into public.duel_players
    (duel_id, user_id, seat, current_q, score, correct, total_ms, started_at, finished_at)
  values
    (made.id, uid, 1, me.current_q, me.score, me.correct, me.total_ms, me.started_at, me.finished_at)
  returning id into new_player;

  insert into public.answers
    (player_id, q_index, question_id, sent_at, answered_at, chosen_idx, is_correct, points)
  select new_player, q_index, question_id, sent_at, answered_at, chosen_idx, is_correct, points
    from public.answers where player_id = me.id;

  return json_build_object('code', made.code);
end $$;


-- ---------------------------------------------------------------------
-- Quick Match
-- Races the recorded run of a real player near your rating, on a set
-- you haven't seen. Only your rating moves. If nobody suitable exists
-- yet, you play a solo run that later players will race.
-- ---------------------------------------------------------------------

create or replace function public.quick_match() returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  my_rating int;
  existing uuid;
  ghost public.duel_players;
  ghost_set bigint;
  d public.duels;
  new_player uuid;
begin
  -- Finish an open quick match before starting another, so a bad run
  -- can't be dodged.
  select x.id into existing
    from public.duels x
    join public.duel_players me on me.duel_id = x.id and me.user_id = uid
   where x.mode = 'quick' and not me.is_replay and me.finished_at is null
   order by x.created_at desc
   limit 1;
  if found then
    return json_build_object('duel_id', existing);
  end if;

  if (select count(*) from public.duels
       where created_by = uid and mode = 'quick'
         and created_at > now() - interval '1 hour') >= 60 then
    raise exception 'That''s a lot of matches. Take a short break and come back.';
  end if;

  select rating into my_rating from public.profiles where id = uid;

  select p.* into ghost
    from public.duel_players p
    join public.duels gd on gd.id = p.duel_id
    join public.profiles gp on gp.id = p.user_id
   where p.user_id <> uid
     and not p.is_replay
     and p.finished_at is not null
     and p.finished_at > now() - interval '60 days'
     and gd.mode <> 'daily'
     and not exists (
       select 1 from public.duel_players mine
         join public.duels md on md.id = mine.duel_id
        where mine.user_id = uid and md.set_id = gd.set_id)
   order by abs(coalesce(p.rating_before, gp.rating) - my_rating) + random() * 150
   limit 1;

  if not found then
    insert into public.duels (code, mode, set_id, created_by)
    values (public._new_code(), 'quick', public._new_set(), uid)
    returning * into d;
    insert into public.duel_players (duel_id, user_id, seat) values (d.id, uid, 1);
    return json_build_object('duel_id', d.id);
  end if;

  select set_id into ghost_set from public.duels where id = ghost.duel_id;
  insert into public.duels (code, mode, set_id, created_by)
  values (public._new_code(), 'quick', ghost_set, uid)
  returning * into d;

  insert into public.duel_players
    (duel_id, user_id, seat, is_replay, current_q, score, correct, total_ms, started_at, finished_at)
  values
    (d.id, ghost.user_id, 1, true, ghost.current_q, ghost.score, ghost.correct, ghost.total_ms,
     ghost.started_at, ghost.finished_at)
  returning id into new_player;

  insert into public.answers
    (player_id, q_index, question_id, sent_at, answered_at, chosen_idx, is_correct, points)
  select new_player, q_index, question_id, sent_at, answered_at, chosen_idx, is_correct, points
    from public.answers where player_id = ghost.id;

  insert into public.duel_players (duel_id, user_id, seat) values (d.id, uid, 2);
  return json_build_object('duel_id', d.id);
end $$;


-- ---------------------------------------------------------------------
-- Daily Challenge: the same 5 questions for everyone, once per day.
-- ---------------------------------------------------------------------

create or replace function public.daily_challenge() returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  v_today date := public._today();
  sid bigint;
  did uuid;
begin
  select set_id into sid from public.daily_sets where day = v_today;
  if not found then
    insert into public.daily_sets (day, set_id) values (v_today, public._new_set())
    on conflict (day) do nothing;
    select set_id into sid from public.daily_sets where day = v_today;
  end if;

  select d.id into did
    from public.duels d
    join public.duel_players p on p.duel_id = d.id and p.user_id = uid
   where d.mode = 'daily' and d.set_id = sid;
  if found then
    return json_build_object('duel_id', did);
  end if;

  insert into public.duels (code, mode, set_id, created_by, expires_at)
  values (public._new_code(), 'daily', sid, uid, now() + interval '1 day')
  returning id into did;
  insert into public.duel_players (duel_id, user_id, seat) values (did, uid, 1);
  return json_build_object('duel_id', did);
end $$;


-- ---------------------------------------------------------------------
-- get_duel: adds today's rank for daily challenge runs.
-- ---------------------------------------------------------------------

create or replace function public.get_duel(p_duel_id uuid) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  d public.duels;
  me public.duel_players;
  opp public.duel_players;
  review json;
  daily json;
  root_code text;
begin
  select * into me from public.duel_players where duel_id = p_duel_id and user_id = uid;
  if not found then
    raise exception 'You are not in this duel.';
  end if;
  select * into d from public.duels where id = p_duel_id;
  select * into opp from public.duel_players where duel_id = p_duel_id and user_id <> uid;
  select code into root_code from public.duels where id = coalesce(d.parent_id, d.id);

  if me.finished_at is not null then
    select json_agg(json_build_object(
             'q_index',     a.q_index,
             'section',     q.section,
             'topic',       q.topic,
             'body',        q.body,
             'options',     q.options,
             'correct_idx', q.correct_idx,
             'chosen_idx',  a.chosen_idx,
             'is_correct',  a.is_correct,
             'points',      a.points,
             'ms',          least((extract(epoch from (a.answered_at - a.sent_at)) * 1000)::int,
                                  q.time_limit_s * 1000),
             'explanation', q.explanation,
             'opp_correct', oa.is_correct
           ) order by a.q_index)
      into review
      from public.answers a
      join public.questions q on q.id = a.question_id
      left join public.answers oa
             on oa.player_id = opp.id and oa.q_index = a.q_index
            and opp.finished_at is not null
     where a.player_id = me.id;
  end if;

  if d.mode = 'daily' and me.finished_at is not null then
    select json_build_object(
             'rank',    1 + count(*) filter (where x.score > me.score
                                               or (x.score = me.score and x.total_ms < me.total_ms)),
             'players', count(*))
      into daily
      from public.duel_players x
      join public.duels xd on xd.id = x.duel_id
     where xd.mode = 'daily' and xd.set_id = d.set_id and x.finished_at is not null;
  end if;

  return json_build_object(
    'id',         d.id,
    'code',       root_code,
    'mode',       d.mode,
    'status',     d.status,
    'is_creator', d.mode = 'challenge' and me.seat = 1 and not me.is_replay,
    'me',         public._player_json(me),
    'opponent',   case when opp.id is null then null else public._player_json(opp) end,
    'review',     review,
    'daily',      daily
  );
end $$;


-- ---------------------------------------------------------------------
-- get_me: adds this week's daily challenge days and today's quests.
-- ---------------------------------------------------------------------

create or replace function public.get_me() returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  v_today date := public._today();
  v_monday date := public._today() - (extract(isodow from public._today())::int - 1);
  r json;
begin
  select json_build_object(
           'id',           p.id,
           'name',         p.display_name,
           'rating',       p.rating,
           'games_played', p.games_played,
           'wins',         p.wins,
           'streak',       case when p.last_played_on >= v_today - 1
                                then p.streak_current else 0 end,
           'streak_best',  p.streak_best,
           'played_today', coalesce(p.last_played_on = v_today, false),
           'college_id',   p.college_id,
           'college',      c.name,
           'grad_year',    p.grad_year,
           'college_rank', case when p.college_id is null then null else
                             (select count(*) + 1 from public.profiles x
                               where x.college_id = p.college_id and x.rating > p.rating
                                 and x.last_played_on is not null) end,
           'today_idx',    v_today - v_monday,
           'daily_week',   (select json_agg(exists (
                                      select 1 from public.duel_players dp
                                        join public.duels dd on dd.id = dp.duel_id
                                       where dp.user_id = uid and dd.mode = 'daily'
                                         and dp.finished_at is not null
                                         and (dp.finished_at at time zone 'Asia/Kolkata')::date = v_monday + i)
                                    order by i)
                              from generate_series(0, 6) as i),
           'quests',       json_build_object(
             'daily', (select count(*) from public.duel_players dp
                         join public.duels dd on dd.id = dp.duel_id
                        where dp.user_id = uid and dd.mode = 'daily' and dp.finished_at is not null
                          and (dp.finished_at at time zone 'Asia/Kolkata')::date = v_today),
             'quick_wins', (select count(*) from public.duel_players dp
                              join public.duels dd on dd.id = dp.duel_id
                              join public.duel_players op on op.duel_id = dd.id and op.id <> dp.id
                             where dp.user_id = uid and dd.mode = 'quick' and not dp.is_replay
                               and dp.finished_at is not null and op.finished_at is not null
                               and (dp.finished_at at time zone 'Asia/Kolkata')::date = v_today
                               and (dp.score > op.score
                                    or (dp.score = op.score and dp.total_ms < op.total_ms))),
             'accepted', (select count(*) from public.duels dd
                           where dd.created_by = uid and dd.mode = 'challenge' and dd.parent_id is null
                             and (dd.created_at at time zone 'Asia/Kolkata')::date = v_today
                             and exists (select 1 from public.duel_players x
                                           join public.duels xd on xd.id = x.duel_id
                                          where x.seat = 2 and (xd.id = dd.id or xd.parent_id = dd.id)))
           )
         )
    into r
    from public.profiles p
    left join public.colleges c on c.id = p.college_id
   where p.id = uid;
  return r;
end $$;


-- ---------------------------------------------------------------------
-- my_duels: adds what the dashboard table needs. Hides runs of yours
-- that other players raced in Quick Match.
-- ---------------------------------------------------------------------

create or replace function public.my_duels(p_limit int default 10) returns json
language sql stable security definer set search_path = '' as $$
  select coalesce(json_agg(x order by x.created_at desc), '[]'::json)
  from (
    select d.id, d.mode, d.status, d.created_at,
           case when d.mode = 'challenge' and me.seat = 1 and not me.is_replay
                then d.code end as code,
           me.seat, me.is_replay,
           me.score, me.correct, me.total_ms, me.finished_at is not null as finished,
           me.rating_before, me.rating_after,
           op.display_name as opponent_name,
           oc.name as opponent_college,
           o.is_replay as opponent_is_replay,
           o.score as opponent_score,
           o.total_ms as opponent_total_ms,
           o.finished_at is not null as opponent_finished
      from public.duel_players me
      join public.duels d on d.id = me.duel_id
      left join public.duel_players o on o.duel_id = d.id and o.id <> me.id
      left join public.profiles op on op.id = o.user_id
      left join public.colleges oc on oc.id = op.college_id
     where me.user_id = auth.uid()
       and not (me.is_replay and d.mode = 'quick')
     order by d.created_at desc
     limit least(greatest(p_limit, 1), 50)
  ) x
$$;


-- ---------------------------------------------------------------------
-- Leaderboards: your college, or all of India. Only players who have
-- played at least once are ranked. week_delta is this week's rating
-- change (weeks start Monday, IST).
-- ---------------------------------------------------------------------

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

  with ranked as (
    select pr.id, pr.display_name, pr.rating, pr.grad_year, c.name as college,
           rank() over (order by pr.rating desc) as rnk,
           coalesce((select sum(dp.rating_after - dp.rating_before)
                       from public.duel_players dp
                      where dp.user_id = pr.id and not dp.is_replay
                        and dp.rating_after is not null
                        and dp.finished_at >= week_start), 0)::int as week_delta
      from public.profiles pr
      left join public.colleges c on c.id = pr.college_id
     where pr.last_played_on is not null
       and (p_scope = 'india' or pr.college_id = my_college)
  )
  select json_build_object(
           'scope',   p_scope,
           'college', (select name from public.colleges where id = my_college),
           'players', (select count(*) from ranked),
           'rows',    coalesce((select json_agg(json_build_object(
                                         'rank',       x.rnk,
                                         'name',       x.display_name,
                                         'rating',     x.rating,
                                         'college',    x.college,
                                         'grad_year',  x.grad_year,
                                         'week_delta', x.week_delta,
                                         'is_me',      x.id = uid)
                                       order by x.rnk, x.display_name)
                                  from (select * from ranked
                                         order by rnk, display_name
                                         limit least(greatest(p_limit, 1), 100)) x),
                               '[]'::json),
           'me',      (select json_build_object(
                                'rank',       x.rnk,
                                'name',       x.display_name,
                                'rating',     x.rating,
                                'college',    x.college,
                                'grad_year',  x.grad_year,
                                'week_delta', x.week_delta,
                                'is_me',      true)
                         from ranked x where x.id = uid)
         ) into r;
  return r;
end $$;


-- Permanently deletes the signed-in player and everything they played.
create or replace function public.delete_me() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in required' using errcode = '28000';
  end if;
  delete from auth.users where id = auth.uid();
end $$;


-- ---------------------------------------------------------------------
-- Permissions: clients may call only the API functions.
-- ---------------------------------------------------------------------

revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function public.get_challenge(text) to anon, authenticated;
grant execute on function
  public.create_challenge(),
  public.join_challenge(text),
  public.challenge_from_duel(uuid),
  public.quick_match(),
  public.daily_challenge(),
  public.next_question(uuid),
  public.submit_answer(uuid, int, int),
  public.get_duel(uuid),
  public.get_me(),
  public.update_profile(text, int, int),
  public.my_duels(int),
  public.leaderboard(text, int),
  public.delete_me()
to authenticated;
