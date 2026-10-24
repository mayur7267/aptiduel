-- =====================================================================
-- AptiDuel · 0003_bots
-- Practice bots, so Quick Match always finds an opponent. A bot plays a
-- simulated run whose accuracy and speed follow its rating, so players
-- win some and lose some. Bots are labelled in the app, never ranked on
-- leaderboards, and their rating never changes.
--
-- Also adds each opponent's answer timeline to get_duel, so the duel
-- screen can show them racing in real time.
--
-- Safe to run more than once.
-- =====================================================================


-- Bots need profiles without a sign-in account, so profiles no longer
-- reference auth.users directly. A trigger keeps them in sync instead.
do $$
declare
  c text;
begin
  select conname into c
    from pg_constraint
   where conrelid = 'public.profiles'::regclass
     and contype = 'f'
     and confrelid = 'auth.users'::regclass;
  if c is not null then
    execute format('alter table public.profiles drop constraint %I', c);
  end if;
end $$;

create or replace function public._on_auth_user_deleted() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.profiles where id = old.id;
  return old;
end $$;

drop trigger if exists on_auth_user_deleted on auth.users;
create trigger on_auth_user_deleted
  after delete on auth.users
  for each row execute function public._on_auth_user_deleted();

alter table public.profiles add column if not exists is_bot boolean not null default false;
alter table public.profiles add column if not exists tagline text;

-- 48 bots with everyday names, rated from 800 to about 1,790 in steps
-- of 21, so there are always a few near any player. The app still tags
-- them as bots.
insert into public.profiles (id, display_name, rating, is_bot, tagline)
select gen_random_uuid(),
       b.name,
       800 + (b.ord - 1) * 21,
       true,
       (array[
         'Fast on percentages', 'Never skips a question', 'Strong in reasoning',
         'Slow and steady', 'Loves time and work', 'Guesses when stuck',
         'Grammar first', 'Trains and clocks expert', 'Practises every night',
         'Number series fan', 'Speed over accuracy', 'Hates leaving blanks'
       ])[1 + ((b.ord - 1) % 12)::int]
  from unnest(array[
    'Rohan K.',    'Diya M.',     'Kabir R.',    'Ananya P.',   'Aarav S.',    'Ishita V.',
    'Arjun N.',    'Meera J.',    'Vihaan T.',   'Sneha G.',    'Aditya B.',   'Kavya L.',
    'Siddharth C.', 'Pooja D.',   'Yash A.',     'Nisha H.',    'Karan W.',    'Riya F.',
    'Harsh Y.',    'Tanvi E.',    'Pranav O.',   'Aditi U.',    'Karthik V.',  'Lakshmi N.',
    'Varun I.',    'Vignesh R.',  'Dev R.',      'Neha B.',     'Rahul M.',    'Anjali S.',
    'Kunal T.',    'Divya K.',    'Manav P.',    'Ritika G.',   'Abhishek N.', 'Simran J.',
    'Akash V.',    'Pallavi C.',  'Ayaan D.',    'Sakshi L.',   'Raghav H.',   'Bhavya A.',
    'Omkar W.',    'Lavanya F.',  'Sameer E.',   'Gauri O.',    'Tejas U.',    'Fatima K.'
  ]) with ordinality as b(name, ord)
 where not exists (
   select 1 from public.profiles p where p.is_bot and p.display_name = b.name);


-- Simulates a bot's run on a duel's questions and seats it as player 1.
-- It's marked as a recorded run, so settling the duel never changes the
-- bot's rating.
create or replace function public._bot_run(p_duel_id uuid, p_bot uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  b public.profiles;
  ids bigint[];
  q public.questions;
  pid uuid;
  t timestamptz := now() - interval '15 minutes';
  skill numeric;
  pace numeric;
  ok boolean;
  limit_ms int;
  ms int;
  pts int;
  v_score int := 0;
  v_correct int := 0;
  v_ms int := 0;
begin
  select * into b from public.profiles where id = p_bot and is_bot;
  select s.question_ids into ids
    from public.duels d join public.duel_sets s on s.id = d.set_id
   where d.id = p_duel_id;

  -- Chance of a correct answer: about 35% at 800, 90% at 1700.
  skill := least(0.92, greatest(0.30, 0.35 + (b.rating - 800) / 1640.0));
  -- Share of the timer used: stronger bots answer sooner.
  pace := least(0.80, greatest(0.30, 0.72 - (b.rating - 800) / 2200.0));

  insert into public.duel_players (duel_id, user_id, seat, is_replay, started_at)
  values (p_duel_id, b.id, 1, true, t)
  returning id into pid;

  for i in 1 .. array_length(ids, 1) loop
    select * into q from public.questions where id = ids[i];
    limit_ms := q.time_limit_s * 1000;
    ok := random() < skill - 0.08 * (q.difficulty - 2);
    ms := (limit_ms * least(0.95, greatest(0.12, pace + (random() - 0.5) * 0.4)))::int;
    pts := case when ok then 100 + round(50 * (1 - ms::numeric / limit_ms))::int else 0 end;

    insert into public.answers
      (player_id, q_index, question_id, sent_at, answered_at, chosen_idx, is_correct, points)
    values
      (pid, i - 1, q.id, t, t + make_interval(secs => ms / 1000.0), null, ok, pts);

    t := t + make_interval(secs => ms / 1000.0);
    v_score := v_score + pts;
    v_correct := v_correct + ok::int;
    v_ms := v_ms + ms;
  end loop;

  update public.duel_players
     set current_q = array_length(ids, 1), score = v_score, correct = v_correct,
         total_ms = v_ms, finished_at = t
   where id = pid;
end $$;


-- ---------------------------------------------------------------------
-- Quick Match: a real player's recorded run if one fits, otherwise a
-- practice bot near your rating.
-- ---------------------------------------------------------------------

create or replace function public.quick_match() returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  my_rating int;
  existing uuid;
  ghost public.duel_players;
  ghost_set bigint;
  bot uuid;
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
     and not gp.is_bot
     and not p.is_replay
     and p.finished_at is not null
     and p.finished_at > now() - interval '60 days'
     and gd.mode <> 'daily'
     and abs(coalesce(p.rating_before, gp.rating) - my_rating) <= 300
     and not exists (
       select 1 from public.duel_players mine
         join public.duels md on md.id = mine.duel_id
        where mine.user_id = uid and md.set_id = gd.set_id)
   order by abs(coalesce(p.rating_before, gp.rating) - my_rating) + random() * 150
   limit 1;

  if found then
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
  else
    select id into bot
      from public.profiles
     where is_bot
     order by abs(rating - my_rating) + random() * 140
     limit 1;

    insert into public.duels (code, mode, set_id, created_by)
    values (public._new_code(), 'quick', public._new_set(), uid)
    returning * into d;
    perform public._bot_run(d.id, bot);
  end if;

  insert into public.duel_players (duel_id, user_id, seat) values (d.id, uid, 2);
  return json_build_object('duel_id', d.id);
end $$;


-- ---------------------------------------------------------------------
-- Player cards now say whether the player is a bot.
-- ---------------------------------------------------------------------

create or replace function public._player_json(p public.duel_players) returns json
language sql stable security definer set search_path = '' as $$
  select json_build_object(
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


-- ---------------------------------------------------------------------
-- get_duel: adds the opponent's timeline (time taken and right/wrong
-- per question, never which option they picked) once their run is done.
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
  timeline json;
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

  if opp.id is not null and opp.finished_at is not null then
    select json_agg(json_build_object(
             'q_index', oa.q_index,
             'ms',      least((extract(epoch from (oa.answered_at - oa.sent_at)) * 1000)::int,
                              q.time_limit_s * 1000),
             'correct', coalesce(oa.is_correct, false),
             'points',  oa.points
           ) order by oa.q_index)
      into timeline
      from public.answers oa
      join public.questions q on q.id = oa.question_id
     where oa.player_id = opp.id and oa.answered_at is not null;
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
    'id',                d.id,
    'code',              root_code,
    'mode',              d.mode,
    'status',            d.status,
    'is_creator',        d.mode = 'challenge' and me.seat = 1 and not me.is_replay,
    'me',                public._player_json(me),
    'opponent',          case when opp.id is null then null else public._player_json(opp) end,
    'opponent_timeline', timeline,
    'review',            review,
    'daily',             daily
  );
end $$;


-- ---------------------------------------------------------------------
-- my_duels: adds whether the opponent was a bot.
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
           coalesce(op.is_bot, false) as opponent_is_bot,
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
-- Leaderboards never include bots.
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
       and not pr.is_bot
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


-- Deletes the profile first: it no longer cascades from auth.users.
create or replace function public.delete_me() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in required' using errcode = '28000';
  end if;
  delete from public.profiles where id = auth.uid();
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
