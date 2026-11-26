-- =====================================================================
-- Apticks · 0031_basics_first
-- Aptitude questions now match the player:
--   * Your first 3 Aptitude duels use basic questions (difficulty 1,
--     from supabase/seed-basics.sql first), against a bot, never a
--     recorded run, so a newcomer's first games are winnable.
--   * After that, the difficulty follows your rating: about half basic
--     at 1,000, mostly medium at 1,200, medium and hard from 1,400.
--   * The Daily, challenge links and new live rooms are unchanged:
--     _new_set() still draws without a level, so the Daily stays a
--     medium mix and the same for everyone.
-- Coding and English are unchanged.
-- Load supabase/seed-basics.sql too (before or after, either works).
-- =====================================================================

-- Aptitude games a player has finished: games_played counts every
-- subject, so take away the Coding and English ones.
create or replace function public._aptitude_games(p_user uuid)
returns int
language sql stable security definer set search_path = '' as $$
  select greatest(0, p.games_played
         - coalesce((select sum(r.games) from public.subject_ratings r where r.user_id = p.id), 0))::int
    from public.profiles p
   where p.id = p_user
$$;

-- The difficulty to aim for, from 1 (basic) to 3 (hard), for these
-- players. Null means no preference (no real players).
--   * Every real player still in their first 3 Aptitude duels: 1.
--   * Otherwise from their average rating: 1.4 at 1,000, 1.9 at 1,200,
--     2.4 at 1,400, between 1.2 and 2.8.
create or replace function public._fit_level(p_users uuid[])
returns real
language sql stable security definer set search_path = '' as $$
  select case
           when count(*) = 0 then null
           when max(public._aptitude_games(p.id)) < 3 then 1
           else least(2.8, greatest(1.2, 1.4 + (avg(p.rating) - 1000) / 400.0))
         end::real
    from public.profiles p
   where p.id = any(p_users) and not p.is_bot
$$;

-- _pick gains p_level. Each of the p_n questions first draws a
-- difficulty, weighted by how close it is to the level: at 1 every
-- question is basic, at 1.4 half basic and half medium, at 1.9 mostly
-- medium with a few of each, at 2.4 half medium and half hard. Then it
-- takes a question of that difficulty the players haven't seen (or
-- missed, as before). For beginners (level 1) the new basic_* questions
-- come first. If a difficulty runs short, the nearest others fill in.
-- Without a level it works exactly as before.
drop function if exists public._pick(uuid[], text, int, boolean, text);
create or replace function public._pick(p_users uuid[], p_section text, p_n int, p_visual boolean default null,
                                        p_company text default null, p_level real default null)
returns setof bigint
language sql security definer set search_path = '' as $$
  with history as (
    select a.question_id,
           max(coalesce(a.answered_at, a.sent_at)) as last_seen,
           bool_or(a.is_correct is not true) as missed
      from public.answers a
      join public.duel_players dp on dp.id = a.player_id
     where dp.user_id = any(p_users) and not dp.is_replay
     group by a.question_id
  ),
  pool as (
    select q.id, q.difficulty,
           h.question_id is not null as seen, h.missed, h.last_seen,
           (p_level <= 1 and q.template like 'basic\_%') as basic_first
      from public.questions q
      left join history h on h.question_id = q.id
     where q.status = 'active'
       and q.section = p_section
       and (p_visual is null or (q.option_figures is not null) = p_visual)
       and (p_company is null or p_company = any(q.company_tags))
  ),
  weights as (
    select greatest(0, 1 - abs(1 - p_level)) as w1,
           greatest(0, 1 - abs(2 - p_level)) as w2,
           greatest(0, 1 - abs(3 - p_level)) as w3
  ),
  slots as (
    select case when s.r * (w.w1 + w.w2 + w.w3) < w.w1 then 1
                when s.r * (w.w1 + w.w2 + w.w3) < w.w1 + w.w2 then 2
                else 3 end as d
      from (select random() as r from generate_series(1, p_n)) s, weights w
     where p_level is not null
  ),
  need as (select d, count(*) as n from slots group by d),
  ranked as (
    select p.id, p.difficulty,
           row_number() over (partition by p.difficulty
                              order by p.seen, p.missed desc, p.last_seen, p.basic_first desc, random()) as rn
      from pool p
  ),
  chosen as (
    select r.id, 0 as pass, r.rn as k
      from ranked r join need n on n.d = r.difficulty and r.rn <= n.n
    union all
    select p.id, 1, row_number() over (
             order by p.seen, p.missed desc, p.last_seen,
                      case when p_level is null then 0 else abs(p.difficulty - p_level) end, random())
      from pool p
  )
  select id from chosen group by id order by min(pass), min(k) limit p_n
$$;
revoke execute on function public._pick(uuid[], text, int, boolean, text, real) from public, anon, authenticated;

-- Aptitude: 3 quant and 2 reasoning (one with pictures when there is
-- one), at the given level.
create or replace function public._aptitude_set(p_users uuid[], p_level real)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  ids bigint[];
  sid bigint;
  pic bigint[];
begin
  select array_agg(id) into pic from public._pick(p_users, 'reasoning', 1, true, null, p_level) id;
  select array_agg(id order by random()) into ids from (
    select public._pick(p_users, 'quant', 3, null, null, p_level) as id
    union all select unnest(pic)
    union all select public._pick(p_users, 'reasoning', 2 - coalesce(array_length(pic, 1), 0), false, null, p_level)
  ) picked;
  if coalesce(array_length(ids, 1), 0) < 5 then
    raise exception 'The question bank is empty. Load the seed first.';
  end if;
  insert into public.duel_sets (question_ids) values (ids) returning id into sid;
  return sid;
end $$;
revoke execute on function public._aptitude_set(uuid[], real) from public, anon, authenticated;

-- Quick Match and live rooms: fitted to the players.
create or replace function public._new_set(p_users uuid[])
returns bigint
language plpgsql security definer set search_path = '' as $$
begin
  return public._aptitude_set(p_users, public._fit_level(p_users));
end $$;

-- The Daily, challenge links and new rooms: no level, as before.
create or replace function public._new_set()
returns bigint
language plpgsql security definer set search_path = '' as $$
begin
  return public._aptitude_set(array[auth.uid()], null);
end $$;

-- Company practice: fitted to you too.
create or replace function public._company_set(p_company text)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  ids bigint[];
  sid bigint;
  me uuid[] := array[auth.uid()];
  lvl real := public._fit_level(array[auth.uid()]);
begin
  select array_agg(id order by random()) into ids from (
    select public._pick(me, 'quant', 2, null, p_company, lvl) as id
    union all select public._pick(me, 'reasoning', 2, null, p_company, lvl)
    union all select public._pick(me, 'verbal', 1, null, p_company, lvl)
  ) picked;
  if coalesce(array_length(ids, 1), 0) < 5 then
    raise exception 'There aren''t enough % questions yet.', p_company;
  end if;
  insert into public.duel_sets (question_ids) values (ids) returning id into sid;
  return sid;
end $$;

revoke execute on function public._aptitude_games(uuid) from public, anon, authenticated;
revoke execute on function public._fit_level(uuid[]) from public, anon, authenticated;

-- Quick Match: as in 0026, except a beginner's Aptitude match skips
-- recorded runs (see "beginner").
create or replace function public.quick_match(p_subject text)
returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  my_rating int;
  existing uuid;
  existing_player uuid;
  existing_subject text;
  ghost public.duel_players;
  ghost_set bigint;
  bot uuid;
  d public.duels;
  new_player uuid;
  -- A newcomer's first Aptitude duels use fresh basic questions, so
  -- they aren't raced on someone else's recorded set.
  beginner boolean := p_subject = 'aptitude' and public._aptitude_games(uid) < 3;
begin
  if p_subject is null or p_subject not in ('aptitude', 'coding', 'english') then
    raise exception 'Unknown subject.';
  end if;

  -- One at a time per player, so a double tap (or a retried request)
  -- can't start two quick matches at once.
  perform pg_advisory_xact_lock(hashtext('quick match:' || uid::text));
  -- Finish an open quick match before starting another, so a bad run
  -- can't be dodged.
  select x.id, me.id, coalesce(xs.subject, 'aptitude') into existing, existing_player, existing_subject
    from public.duels x
    join public.duel_players me on me.duel_id = x.id and me.user_id = uid
    left join public.duel_sets xs on xs.id = x.set_id
   where x.mode = 'quick' and not me.is_replay and me.finished_at is null
   order by x.created_at desc
   limit 1;
  if found then
    -- A run in another subject ends as it stands: you asked for this
    -- subject, so that's what you get. So does a run whose open question
    -- ran out (with the same 1.5 s grace as submit_answer). Otherwise
    -- carry on with it.
    if existing_subject <> p_subject or exists (
      select 1 from public.answers a join public.questions q on q.id = a.question_id
       where a.player_id = existing_player and a.answered_at is null
         and now() > a.sent_at + make_interval(secs => q.time_limit_s + 1.5)) then
      perform public._forfeit_run(existing_player);
    else
      return json_build_object('duel_id', existing, 'resumed', true);
    end if;
  end if;

  if (select count(*) from public.duels
       where created_by = uid and mode = 'quick'
         and created_at > now() - interval '1 hour') >= 60 then
    raise exception 'That''s a lot of matches. Take a short break and come back.';
  end if;

  my_rating := public._rating(uid, p_subject);

  select p.* into ghost
    from public.duel_players p
    join public.duels gd on gd.id = p.duel_id
    join public.duel_sets gs on gs.id = gd.set_id
    join public.profiles gp on gp.id = p.user_id
   where p.user_id <> uid
     and gs.subject = p_subject
     -- Aptitude no longer has a verbal question (English does): older
     -- Aptitude sets that have one aren't raced again.
     and (p_subject <> 'aptitude' or not exists (
           select 1 from unnest(gs.question_ids) qi join public.questions q on q.id = qi
            where q.section = 'verbal'))
     and not beginner
     and not gp.is_bot
     and gp.deleted_at is null
     and not p.is_replay
     and p.finished_at is not null
     and p.finished_at > now() - interval '60 days'
     and gd.mode <> 'daily'
     -- Only runs someone really played: an answer chosen on at least 4
     -- of the 5 questions, and at least one right.
     and p.correct >= 1
     and (select count(*) from public.answers ga
           where ga.player_id = p.id and ga.chosen_idx is not null) >= 4
     -- Never today's daily set: playing it early would spoil the daily.
     and not exists (select 1 from public.daily_sets ds
                      where ds.set_id = gd.set_id and ds.day >= public._today())
     and abs(coalesce(p.rating_before, public._rating(gp.id, p_subject)) - my_rating) <= 300
     and not exists (
       select 1 from public.duel_players mine
         join public.duels md on md.id = mine.duel_id
        where mine.user_id = uid and md.set_id = gd.set_id)
   order by abs(coalesce(p.rating_before, public._rating(gp.id, p_subject)) - my_rating) + random() * 150
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
    -- A bot of this subject near your rating: Coding and English bots
    -- have a rating in their subject; Aptitude's bots have none.
    select p.id into bot
      from public.profiles p
      left join public.subject_ratings r on r.user_id = p.id and r.subject = p_subject
     where p.is_bot and p.deleted_at is null
       and case when p_subject = 'aptitude'
                then not exists (select 1 from public.subject_ratings x where x.user_id = p.id)
                else r.user_id is not null end
     order by abs(coalesce(r.rating, p.rating) - my_rating) + random() * 140
     limit 1;
    if bot is null then
      select id into bot
        from public.profiles
       where is_bot
       order by abs(rating - my_rating) + random() * 140
       limit 1;
    end if;

    insert into public.duels (code, mode, set_id, created_by)
    values (public._new_code(), 'quick', public._new_set(array[uid], p_subject), uid)
    returning * into d;
    perform public._bot_run(d.id, bot);
  end if;

  insert into public.duel_players (duel_id, user_id, seat) values (d.id, uid, 2);
  return json_build_object('duel_id', d.id, 'resumed', false);
end $$;

