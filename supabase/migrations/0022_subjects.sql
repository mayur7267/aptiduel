-- Subjects. Every duel so far is Aptitude; Coding is the second subject:
-- short programs, "what does this print?", shown in the language each
-- player picks (C, C++, Java, Python or pseudocode). The questions come
-- from scripts/generate-coding.ts (supabase/seed-coding.sql).
--
-- A subject belongs to a question set, so every copy of a set (a
-- challenge link, a recorded opponent) keeps it without any change to
-- the functions that copy sets. Coding has its own rating: a strong
-- coder isn't held back by their aptitude rating, or the other way round.
--
-- Nothing changes for apps already out: quick_match() with no argument
-- is Aptitude, exactly as before, and profiles.rating stays the Aptitude
-- rating.

-- Questions ------------------------------------------------------------

alter table public.questions drop constraint if exists questions_section_check;
alter table public.questions add constraint questions_section_check
  check (section in ('quant', 'reasoning', 'verbal', 'coding'));

-- The program in each language: {"c", "cpp", "java", "python", "pseudo"}.
alter table public.questions add column if not exists code jsonb;

-- Sets and ratings -----------------------------------------------------

alter table public.duel_sets add column if not exists subject text not null default 'aptitude';
alter table public.duel_sets drop constraint if exists duel_sets_subject_check;
alter table public.duel_sets add constraint duel_sets_subject_check check (subject in ('aptitude', 'coding'));

-- Ratings for every subject but Aptitude (that one is profiles.rating).
create table if not exists public.subject_ratings (
  user_id uuid not null references public.profiles (id) on delete cascade,
  subject text not null check (subject in ('coding')),
  rating  int  not null default 1000,
  games   int  not null default 0,
  wins    int  not null default 0,
  primary key (user_id, subject)
);
create index if not exists subject_ratings_board on public.subject_ratings (subject, rating desc);
-- Only read through the functions below.
alter table public.subject_ratings enable row level security;

-- A player's rating in a subject. Bots keep one strength everywhere.
create or replace function public._rating(p_user uuid, p_subject text) returns int
language sql stable security definer set search_path = '' as $$
  select case when p_subject = 'aptitude' or p.is_bot then p.rating
              else coalesce(r.rating, 1000) end
    from public.profiles p
    left join public.subject_ratings r on r.user_id = p.id and r.subject = p_subject
   where p.id = p_user
$$;

-- Your rating and games in each subject, for Home and Profile. Not
-- `stable`: _require_player can create your profile, and Supabase runs
-- stable functions read-only.
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
                                       where user_id = uid and subject = 'coding'), 0)));
end $$;

-- Question sets --------------------------------------------------------

-- Five coding questions on five different topics, preferring ones the
-- players haven't seen (and ones they missed), as _pick does.
create or replace function public._new_set(p_users uuid[], p_subject text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  ids bigint[];
  sid bigint;
begin
  if p_subject = 'aptitude' then
    return public._new_set(p_users);
  elsif p_subject <> 'coding' then
    raise exception 'Unknown subject.';
  end if;

  select array_agg(id order by random()) into ids from (
    select id from (
      select distinct on (q.topic) c.id, c.ord
        from unnest(array(select public._pick(p_users, 'coding', 60))) with ordinality as c (id, ord)
        join public.questions q on q.id = c.id
       order by q.topic, c.ord) per_topic
     order by ord
     limit 5) chosen;
  if coalesce(array_length(ids, 1), 0) < 5 then
    raise exception 'Coding questions aren''t loaded yet.';
  end if;
  insert into public.duel_sets (question_ids, subject) values (ids, 'coding') returning id into sid;
  return sid;
end $$;

-- Quick Match in a subject ---------------------------------------------

-- quick_match() as before, with the opponent, the questions and the
-- rating all taken from the chosen subject.
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
  if p_subject is null or p_subject not in ('aptitude', 'coding') then
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

-- Ratings --------------------------------------------------------------

-- As before, with the rating read from and written to the duel's subject.
-- Games and wins on the profile count every subject.
create or replace function public._settle_duel(p_duel_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  d public.duels;
  subj text;
  p1 public.duel_players;
  p2 public.duel_players;
  r1 int; g1 int;
  r2 int; g2 int;
  s1 numeric;  -- seat 1's result: 1 win, 0.5 draw, 0 loss
  e1 numeric;  -- seat 1's expected result
  n1 int; n2 int;
begin
  select * into d from public.duels where id = p_duel_id;
  select coalesce(s.subject, 'aptitude') into subj from public.duel_sets s where s.id = d.set_id;
  subj := coalesce(subj, 'aptitude');
  select * into p1 from public.duel_players where duel_id = p_duel_id and seat = 1 for update;
  select * into p2 from public.duel_players where duel_id = p_duel_id and seat = 2 for update;
  if p1.id is null or p2.id is null
     or p1.finished_at is null or p2.finished_at is null
     or p2.rating_after is not null then
    return;
  end if;

  select rating, games_played into r1, g1 from public.profiles where id = p1.user_id for update;
  select rating, games_played into r2, g2 from public.profiles where id = p2.user_id for update;
  if subj <> 'aptitude' then
    r1 := public._rating(p1.user_id, subj);
    r2 := public._rating(p2.user_id, subj);
    g1 := coalesce((select games from public.subject_ratings where user_id = p1.user_id and subject = subj), 0);
    g2 := coalesce((select games from public.subject_ratings where user_id = p2.user_id and subject = subj), 0);
  end if;

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
  elsif subj = 'aptitude' then
    update public.profiles
       set rating = n1, games_played = games_played + 1, wins = wins + (s1 = 1)::int
     where id = p1.user_id;
  else
    update public.profiles
       set games_played = games_played + 1, wins = wins + (s1 = 1)::int
     where id = p1.user_id;
    insert into public.subject_ratings as sr (user_id, subject, rating, games, wins)
    values (p1.user_id, subj, n1, 1, (s1 = 1)::int)
    on conflict (user_id, subject) do update
      set rating = excluded.rating, games = sr.games + 1, wins = sr.wins + excluded.wins;
  end if;

  if subj = 'aptitude' then
    update public.profiles
       set rating = n2, games_played = games_played + 1, wins = wins + (s1 = 0)::int
     where id = p2.user_id;
  else
    update public.profiles
       set games_played = games_played + 1, wins = wins + (s1 = 0)::int
     where id = p2.user_id;
    insert into public.subject_ratings as sr (user_id, subject, rating, games, wins)
    values (p2.user_id, subj, n2, 1, (s1 = 0)::int)
    on conflict (user_id, subject) do update
      set rating = excluded.rating, games = sr.games + 1, wins = sr.wins + excluded.wins;
  end if;

  update public.duel_players set rating_before = r1, rating_after = n1 where id = p1.id;
  update public.duel_players set rating_before = r2, rating_after = n2 where id = p2.id;
  update public.duels set status = 'complete' where id = p_duel_id;
end $$;

-- Questions and results carry the code -----------------------------------

-- As before, plus the program (code) for coding questions.
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
    'code',           q.code,
    'options',        q.options,
    'option_figures', q.option_figures,
    'time_limit_ms',  q.time_limit_s * 1000,
    'remaining_ms',   greatest(0, q.time_limit_s * 1000 - elapsed_ms),
    'score',          p.score
  );
end $$;

-- As before, plus the duel's subject and each reviewed question's code.
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
             'companies',      q.company_tags,
             'body',           q.body,
             'figure',         q.figure,
             'code',           q.code,
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
    'subject',           coalesce((select s.subject from public.duel_sets s where s.id = d.set_id), 'aptitude'),
    'company',           d.company,
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

-- Players and duel lists ---------------------------------------------------

-- As before, but 'rating' is the rating in the duel's subject.
create or replace function public._player_json(p public.duel_players) returns json
language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'id',            p.user_id,
    'seat',          p.seat,
    'name',          pr.display_name,
    'rating',        public._rating(p.user_id, coalesce(
                       (select s.subject from public.duels d join public.duel_sets s on s.id = d.set_id
                         where d.id = p.duel_id), 'aptitude')),
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

-- Your duels in every subject, with the subject, for the website.
create or replace function public.my_duels_all(p_limit integer default 10) returns json
language sql stable security definer set search_path = '' as $$
  select coalesce(json_agg(x order by x.created_at desc), '[]'::json)
  from (
    select d.id, d.mode, d.company, d.status, d.created_at,
           coalesce(s.subject, 'aptitude') as subject,
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
      left join public.duel_sets s on s.id = d.set_id
      left join public.duel_players o on o.duel_id = d.id and o.id <> me.id
      left join public.profiles op on op.id = o.user_id
      left join public.colleges oc on oc.id = op.college_id
     where me.user_id = auth.uid()
       and not (me.is_replay and d.mode = 'quick')
     order by d.created_at desc
     limit least(greatest(p_limit, 1), 50)
  ) x
$$;

-- The apps already out draw their rating chart from my_duels, which
-- only knows one rating: they keep seeing Aptitude duels only.
create or replace function public.my_duels(p_limit integer default 10) returns json
language sql stable security definer set search_path = '' as $$
  select coalesce(json_agg(x order by x.created_at desc), '[]'::json)
  from (
    select d.id, d.mode, d.company, d.status, d.created_at,
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
      left join public.duel_sets s on s.id = d.set_id
      left join public.duel_players o on o.duel_id = d.id and o.id <> me.id
      left join public.profiles op on op.id = o.user_id
      left join public.colleges oc on oc.id = op.college_id
     where me.user_id = auth.uid()
       and not (me.is_replay and d.mode = 'quick')
       and coalesce(s.subject, 'aptitude') = 'aptitude'
     order by d.created_at desc
     limit least(greatest(p_limit, 1), 50)
  ) x
$$;

-- Who may call what: helpers stay internal, players (guests included are
-- signed in) get the two new calls.
revoke execute on function public._rating(uuid, text) from public, anon, authenticated;
revoke execute on function public._new_set(uuid[], text) from public, anon, authenticated;
revoke execute on function public.my_subjects() from public, anon;
grant execute on function public.my_subjects() to authenticated;
revoke execute on function public.quick_match(text) from public, anon;
grant execute on function public.quick_match(text) to authenticated;
revoke execute on function public.my_duels_all(integer) from public, anon;
grant execute on function public.my_duels_all(integer) to authenticated;
