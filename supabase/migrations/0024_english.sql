-- =====================================================================
-- Apticks · 0024_english
-- English becomes the third subject: duels of five verbal questions on
-- five different topics (synonyms, idioms, grammar, voice, reported
-- speech and more; supabase/seed-verbal-*.sql), with its own rating, in
-- Quick Match and friend duels. Aptitude becomes 3 quant + 2 reasoning:
-- its verbal question moves to English. The Daily follows Aptitude.
-- Company practice keeps its verbal question, as the real tests have one.
--
-- Also: quick_match() with no subject (the website's Aptitude call and
-- the apps already out) now goes through quick_match('aptitude'), so a
-- recorded Coding or English run can never be its opponent.
--
-- Apps already out show English questions fine (plain text), so nobody
-- is kept out of an English duel.
-- Safe to run more than once.
-- =====================================================================

alter table public.duel_sets drop constraint if exists duel_sets_subject_check;
alter table public.duel_sets add constraint duel_sets_subject_check
  check (subject in ('aptitude', 'coding', 'english'));
alter table public.subject_ratings drop constraint if exists subject_ratings_subject_check;
alter table public.subject_ratings add constraint subject_ratings_subject_check
  check (subject in ('coding', 'english'));

-- Question sets --------------------------------------------------------

-- Aptitude: 3 quant and 2 reasoning (one with pictures when there is one).
create or replace function public._new_set(p_users uuid[]) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  ids bigint[];
  sid bigint;
  pic bigint[];
begin
  select array_agg(id) into pic from public._pick(p_users, 'reasoning', 1, true) id;
  select array_agg(id order by random()) into ids from (
    select public._pick(p_users, 'quant', 3) as id
    union all select unnest(pic)
    union all select public._pick(p_users, 'reasoning', 2 - coalesce(array_length(pic, 1), 0), false)
  ) picked;
  if coalesce(array_length(ids, 1), 0) < 5 then
    raise exception 'The question bank is empty. Load the seed first.';
  end if;
  insert into public.duel_sets (question_ids) values (ids) returning id into sid;
  return sid;
end $$;

-- Coding and English: five questions on five different topics, preferring
-- ones the players haven't seen (and ones they missed), as _pick does.
create or replace function public._new_set(p_users uuid[], p_subject text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  ids bigint[];
  sid bigint;
  sec text;
begin
  if p_subject = 'aptitude' then
    return public._new_set(p_users);
  end if;
  sec := case p_subject when 'coding' then 'coding' when 'english' then 'verbal' end;
  if sec is null then
    raise exception 'Unknown subject.';
  end if;

  select array_agg(id order by random()) into ids from (
    select id from (
      select distinct on (q.topic) c.id, c.ord
        from unnest(array(select public._pick(p_users, sec, 60))) with ordinality as c (id, ord)
        join public.questions q on q.id = c.id
       order by q.topic, c.ord) per_topic
     order by ord
     limit 5) chosen;
  if coalesce(array_length(ids, 1), 0) < 5 then
    raise exception 'Questions for this subject aren''t loaded yet.';
  end if;
  insert into public.duel_sets (question_ids, subject) values (ids, p_subject) returning id into sid;
  return sid;
end $$;

-- Ratings ----------------------------------------------------------------

create or replace function public.my_subjects() returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
begin
  return json_build_object(
    'aptitude', (select json_build_object('rating', p.rating, 'games', p.games_played)
                   from public.profiles p where p.id = uid),
    'coding',   json_build_object(
                  'rating', public._rating(uid, 'coding'),
                  'games',  coalesce((select games from public.subject_ratings
                                       where user_id = uid and subject = 'coding'), 0)),
    'english',  json_build_object(
                  'rating', public._rating(uid, 'english'),
                  'games',  coalesce((select games from public.subject_ratings
                                       where user_id = uid and subject = 'english'), 0)));
end $$;

-- Quick Match ------------------------------------------------------------

-- quick_match (0022) with English, and Aptitude never racing an older
-- set that still has a verbal question.
create or replace function public.quick_match(p_subject text) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  my_rating int;
  existing uuid;
  existing_player uuid;
  ghost public.duel_players;
  ghost_set bigint;
  bot uuid;
  d public.duels;
  new_player uuid;
begin
  if p_subject is null or p_subject not in ('aptitude', 'coding', 'english') then
    raise exception 'Unknown subject.';
  end if;

  -- One at a time per player, so a double tap (or a retried request)
  -- can't start two quick matches at once.
  perform pg_advisory_xact_lock(hashtext('quick match:' || uid::text));
  -- Finish an open quick match (in any subject) before starting another,
  -- so a bad run can't be dodged.
  select x.id, me.id into existing, existing_player
    from public.duels x
    join public.duel_players me on me.duel_id = x.id and me.user_id = uid
   where x.mode = 'quick' and not me.is_replay and me.finished_at is null
   order by x.created_at desc
   limit 1;
  if found then
    -- You left and the open question ran out (with the same 1.5 s grace
    -- as submit_answer): that run is over, so start a new one.
    if exists (
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
    select id into bot
      from public.profiles
     where is_bot
     order by abs(rating - my_rating) + random() * 140
     limit 1;

    insert into public.duels (code, mode, set_id, created_by)
    values (public._new_code(), 'quick', public._new_set(array[uid], p_subject), uid)
    returning * into d;
    perform public._bot_run(d.id, bot);
  end if;

  insert into public.duel_players (duel_id, user_id, seat) values (d.id, uid, 2);
  return json_build_object('duel_id', d.id, 'resumed', false);
end $$;

-- The original call is Aptitude.
create or replace function public.quick_match() returns json
language plpgsql security definer set search_path = '' as $$
begin
  return public.quick_match('aptitude');
end $$;

-- Friend duels ------------------------------------------------------------

-- create_room and set_room_subject (0023) with English.
create or replace function public.create_room(p_subject text) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_member();
  d public.duels;
begin
  if p_subject is null or p_subject not in ('aptitude', 'coding', 'english') then
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

create or replace function public.set_room_subject(p_duel_id uuid, p_subject text) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_member();
  d public.duels;
begin
  if p_subject is null or p_subject not in ('aptitude', 'coding', 'english') then
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

notify pgrst, 'reload schema';
