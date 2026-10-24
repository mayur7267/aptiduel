-- =====================================================================
-- AptiDuel · 0006_fixes
-- Found in QA:
--  * Two quick matches (or daily runs) could start at once when a request
--    was sent twice. They now take a per-player lock.
--  * Refreshing mid-duel lost your right/wrong dots. get_duel now returns
--    your own answers so far.
--  * Some number analogies fit two rules. Those are retired.
-- Safe to run more than once.
-- =====================================================================

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
  -- One at a time per player, so a double tap (or a retried request)
  -- can't start two quick matchs at once.
  perform pg_advisory_xact_lock(hashtext('quick match:' || uid::text));
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

create or replace function public.daily_challenge() returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  v_today date := public._today();
  sid bigint;
  did uuid;
begin
  -- One at a time per player, so a double tap (or a retried request)
  -- can't start two daily challenges at once.
  perform pg_advisory_xact_lock(hashtext('daily challenge:' || uid::text));
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
  mine json;
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
             'q_index',        a.q_index,
             'section',        q.section,
             'topic',          q.topic,
             'body',           q.body,
             'figure',         q.figure,
             'options',        q.options,
             'option_figures', q.option_figures,
             'correct_idx',    q.correct_idx,
             'chosen_idx',     a.chosen_idx,
             'is_correct',     a.is_correct,
             'points',         a.points,
             'ms',             least((extract(epoch from (a.answered_at - a.sent_at)) * 1000)::int,
                                     q.time_limit_s * 1000),
             'explanation',    q.explanation,
             'opp_correct',    oa.is_correct
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

  select json_agg(json_build_object('q_index', a.q_index, 'correct', coalesce(a.is_correct, false))
                  order by a.q_index)
    into mine
    from public.answers a
   where a.player_id = me.id and a.answered_at is not null;

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
    'my_answers',        mine,
    'review',            review,
    'daily',             daily
  );
end $$;

-- Retire number analogies that also fit a second obvious rule (3 : 9
-- is both "×3" and "square", for example). Their answer is debatable.
with parsed as (
  select q.id,
         m[1]::int as a, m[2]::int as fa, m[3]::int as b,
         q.options[q.correct_idx + 1]::int as ans,
         q.options
    from public.questions q,
         regexp_match(q.body, 'Find the missing number\. (\d+) : (\d+) :: (\d+) : \?') as m
   where q.template = 'number_analogy' and q.status = 'active'
)
update public.questions q
   set status = 'retired'
  from parsed p
 where q.id = p.id
   and (
     exists (
       select 1
         from (values
           (p.a * p.a, p.b * p.b), (3 * p.a, 3 * p.b), (2 * p.a, 2 * p.b),
           (p.a * p.a * p.a, p.b * p.b * p.b), (p.a * p.a + 1, p.b * p.b + 1),
           (p.a * p.a - 1, p.b * p.b - 1), (p.a * (p.a + 1), p.b * (p.b + 1)),
           (2 * p.a + 3, 2 * p.b + 3)
         ) as alt(ga, gb)
        where alt.ga = p.fa and alt.gb <> p.ans)
     -- "add the same number" also fits; only a problem if its answer is an option
     or ((p.b + p.fa - p.a) <> p.ans and (p.b + p.fa - p.a)::text = any(p.options))
   );
