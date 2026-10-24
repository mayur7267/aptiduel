-- =====================================================================
-- AptiDuel · 0001_init
-- Tables, row-level security and every game rule.
--
-- The website and the iOS app never touch game tables directly. They
-- call the functions at the bottom of this file, which run on the
-- server, check answers, time each question and update ratings. That
-- keeps one source of truth and stops players from cheating.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

create table public.colleges (
  id   serial primary key,
  name text not null unique,
  city text
);

create table public.profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  display_name   text not null default 'Player',
  college_id     int references public.colleges (id),
  grad_year      smallint check (grad_year between 2020 and 2035),
  rating         int not null default 1000,
  games_played   int not null default 0,
  wins           int not null default 0,
  streak_current int not null default 0,
  streak_best    int not null default 0,
  last_played_on date,
  created_at     timestamptz not null default now()
);

create table public.questions (
  id            bigserial primary key,
  section       text not null check (section in ('quant', 'reasoning', 'verbal')),
  topic         text not null,
  difficulty    smallint not null check (difficulty between 1 and 3),
  body          text not null unique,
  options       text[] not null check (array_length(options, 1) = 4),
  correct_idx   smallint not null check (correct_idx between 0 and 3),
  explanation   text not null,
  time_limit_s  smallint not null default 40,
  company_tags  text[] not null default '{}',
  template      text,                       -- generator template that produced it
  served        int not null default 0,     -- times answered in a duel
  correct_count int not null default 0,
  total_ms      bigint not null default 0,  -- for average solve time
  status        text not null default 'active' check (status in ('active', 'retired')),
  created_at    timestamptz not null default now()
);

-- A fixed group of 5 questions. Sets are reused so a later player can
-- face an earlier player's recorded run on exactly the same questions.
create table public.duel_sets (
  id           bigserial primary key,
  question_ids bigint[] not null check (array_length(question_ids, 1) = 5),
  created_at   timestamptz not null default now()
);

create table public.duels (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,          -- short code used in share links
  mode       text not null check (mode in ('challenge', 'quick', 'daily')),
  set_id     bigint not null references public.duel_sets (id),
  created_by uuid not null references public.profiles (id) on delete cascade,
  parent_id  uuid references public.duels (id) on delete cascade, -- copy of a challenge for a later acceptor
  status     text not null default 'open' check (status in ('open', 'complete')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days'
);

create table public.duel_players (
  id            uuid primary key default gen_random_uuid(),
  duel_id       uuid not null references public.duels (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  seat          smallint not null check (seat in (1, 2)),
  is_replay     boolean not null default false, -- recorded run copied from another duel
  current_q     smallint not null default 0,    -- index of the next question to answer
  score         int not null default 0,
  correct       int not null default 0,
  total_ms      int not null default 0,
  started_at    timestamptz not null default now(),
  finished_at   timestamptz,
  rating_before int,
  rating_after  int,
  unique (duel_id, user_id),
  unique (duel_id, seat)
);

create table public.answers (
  player_id   uuid not null references public.duel_players (id) on delete cascade,
  q_index     smallint not null check (q_index between 0 and 4),
  question_id bigint not null references public.questions (id),
  sent_at     timestamptz not null default now(), -- server time the question was shown
  answered_at timestamptz,
  chosen_idx  smallint,
  is_correct  boolean,
  points      int not null default 0,
  primary key (player_id, q_index)
);

create index questions_pick_idx on public.questions (section) where status = 'active';
create index duel_players_user_idx on public.duel_players (user_id);
create index duels_parent_idx on public.duels (parent_id);
create index profiles_college_rating_idx on public.profiles (college_id, rating desc);


-- ---------------------------------------------------------------------
-- Row-level security
-- Colleges and profiles are public to read. Everything else is only
-- reachable through the functions below.
-- ---------------------------------------------------------------------

alter table public.colleges     enable row level security;
alter table public.profiles     enable row level security;
alter table public.questions    enable row level security;
alter table public.duel_sets    enable row level security;
alter table public.duels        enable row level security;
alter table public.duel_players enable row level security;
alter table public.answers      enable row level security;

create policy "colleges are public" on public.colleges
  for select to anon, authenticated using (true);
create policy "profiles are public" on public.profiles
  for select to anon, authenticated using (true);

revoke insert, update, delete on public.colleges, public.profiles from anon, authenticated;
revoke all on public.questions, public.duel_sets, public.duels, public.duel_players, public.answers
  from anon, authenticated;


-- ---------------------------------------------------------------------
-- Internal helpers (not callable by clients)
-- ---------------------------------------------------------------------

-- Today's date in India, so streaks roll over at midnight IST.
create function public._today() returns date
language sql stable set search_path = '' as $$
  select (now() at time zone 'Asia/Kolkata')::date
$$;

-- The signed-in player's id. Creates their profile on first use.
-- Guests (anonymous sign-ins) get a profile too.
create function public._require_player() returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Sign in required' using errcode = '28000';
  end if;
  insert into public.profiles (id, display_name)
  values (uid, 'Player ' || lpad(floor(random() * 10000)::int::text, 4, '0'))
  on conflict (id) do nothing;
  return uid;
end $$;

create function public._new_code() returns text
language plpgsql set search_path = '' as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; -- no 0/O, 1/I/L
  c text;
begin
  loop
    c := '';
    for i in 1..6 loop
      c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.duels where code = c);
  end loop;
  return c;
end $$;

-- 2 quant + 2 reasoning + 1 verbal, in random order.
create function public._new_set() returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  ids bigint[];
  sid bigint;
begin
  select array_agg(id order by random()) into ids
  from (
    (select id from public.questions where status = 'active' and section = 'quant'
      order by random() limit 2)
    union all
    (select id from public.questions where status = 'active' and section = 'reasoning'
      order by random() limit 2)
    union all
    (select id from public.questions where status = 'active' and section = 'verbal'
      order by random() limit 1)
  ) picked;

  if coalesce(array_length(ids, 1), 0) < 5 then
    raise exception 'The question bank is empty. Load the seed first.';
  end if;

  insert into public.duel_sets (question_ids) values (ids) returning id into sid;
  return sid;
end $$;

create function public._player_json(p public.duel_players) returns json
language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'seat',          p.seat,
    'name',          pr.display_name,
    'rating',        pr.rating,
    'college',       c.name,
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

-- Daily streak: playing on consecutive days (IST) keeps it going.
create function public._touch_streak(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.profiles set
    streak_current = case
      when last_played_on = public._today()     then streak_current
      when last_played_on = public._today() - 1 then streak_current + 1
      else 1
    end,
    last_played_on = public._today()
  where id = p_user;

  update public.profiles set streak_best = greatest(streak_best, streak_current)
  where id = p_user;
end $$;

-- Once both players have finished, decide the winner and update Elo
-- ratings. Higher score wins; equal scores go to the faster player.
-- A replayed run (challenge copy) never changes the original player's
-- rating, so one challenge link can't be farmed.
create function public._settle_duel(p_duel_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  p1 public.duel_players;
  p2 public.duel_players;
  r1 int; g1 int;
  r2 int; g2 int;
  s1 numeric;  -- seat 1's result: 1 win, 0.5 draw, 0 loss
  e1 numeric;  -- seat 1's expected result
  n1 int; n2 int;
begin
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


-- ---------------------------------------------------------------------
-- Client API
-- ---------------------------------------------------------------------

-- Start a new challenge. The creator plays first, then shares the code.
create function public.create_challenge() returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  d public.duels;
begin
  if (select count(*) from public.duels
       where created_by = uid and parent_id is null
         and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'Too many new duels. Try again in a few minutes.';
  end if;

  insert into public.duels (code, mode, set_id, created_by)
  values (public._new_code(), 'challenge', public._new_set(), uid)
  returning * into d;

  insert into public.duel_players (duel_id, user_id, seat) values (d.id, uid, 1);
  return json_build_object('duel_id', d.id, 'code', d.code);
end $$;

-- Public info for a challenge link. Works without signing in so the
-- landing page and its WhatsApp preview can show who sent it.
create function public.get_challenge(p_code text) returns json
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
  where d.code = upper(btrim(p_code)) and d.parent_id is null
$$;

-- Accept a challenge. The first person to accept joins the original
-- duel. Anyone after that (say, the rest of a WhatsApp group) gets their
-- own copy against the challenger's recorded run.
create function public.join_challenge(p_code text) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  d public.duels;
  src public.duel_players;
  new_duel uuid;
  new_player uuid;
begin
  select * into d from public.duels
   where code = upper(btrim(p_code)) and parent_id is null
   for update;
  if not found then
    raise exception 'Challenge not found.';
  end if;

  -- Already in it (the challenger, or the first acceptor coming back).
  if exists (select 1 from public.duel_players where duel_id = d.id and user_id = uid) then
    return json_build_object('duel_id', d.id);
  end if;

  -- Already has a copy of it.
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

-- Turn a finished run into a challenge link carrying the player's own
-- score on the same 5 questions, so everyone who plays can share. The
-- challenger of a duel just gets the original link back.
create function public.challenge_from_duel(p_duel_id uuid) returns json
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

  if me.seat = 1 then
    return json_build_object('code', (select code from public.duels where id = coalesce(d.parent_id, d.id)));
  end if;

  select * into made from public.duels
   where parent_id is null and created_by = uid and set_id = d.set_id;
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

-- The current question for the signed-in player. The clock starts the
-- first time a question is sent and keeps running across refreshes.
-- The correct answer is never sent here.
create function public.next_question(p_duel_id uuid) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  p public.duel_players;
  qid bigint;
  q public.questions;
  a public.answers;
  elapsed_ms int;
begin
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

  insert into public.answers (player_id, q_index, question_id)
  values (p.id, p.current_q, qid)
  on conflict (player_id, q_index) do nothing;
  select * into a from public.answers where player_id = p.id and q_index = p.current_q;

  elapsed_ms := (extract(epoch from (now() - a.sent_at)) * 1000)::int;
  return json_build_object(
    'done',          false,
    'q_index',       p.current_q,
    'total',         5,
    'section',       q.section,
    'topic',         q.topic,
    'difficulty',    q.difficulty,
    'body',          q.body,
    'options',       q.options,
    'time_limit_ms', q.time_limit_s * 1000,
    'remaining_ms',  greatest(0, q.time_limit_s * 1000 - elapsed_ms),
    'score',         p.score
  );
end $$;

-- Answer the current question. p_choice is 0-3, or null when time ran
-- out. Correct answers earn 100 points plus up to 50 for speed.
create function public.submit_answer(p_duel_id uuid, p_q_index int, p_choice int default null)
returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  p public.duel_players;
  a public.answers;
  q public.questions;
  limit_ms int;
  elapsed_ms int;
  ok boolean;
  pts int := 0;
begin
  select * into p from public.duel_players
   where duel_id = p_duel_id and user_id = uid
   for update;
  if not found then
    raise exception 'You are not in this duel.';
  end if;
  if p.finished_at is not null then
    raise exception 'This duel is already finished.';
  end if;
  if p_q_index is distinct from p.current_q::int then
    raise exception 'That question was already answered.';
  end if;

  select * into a from public.answers where player_id = p.id and q_index = p.current_q;
  if not found then
    raise exception 'Open the question before answering it.';
  end if;
  select * into q from public.questions where id = a.question_id;

  limit_ms := q.time_limit_s * 1000;
  elapsed_ms := (extract(epoch from (now() - a.sent_at)) * 1000)::int;

  -- 1.5 s of grace for slow networks.
  ok := p_choice is not null and p_choice between 0 and 3
        and elapsed_ms <= limit_ms + 1500
        and p_choice = q.correct_idx;
  elapsed_ms := least(elapsed_ms, limit_ms);
  if ok then
    pts := 100 + round(50 * greatest(0, 1 - elapsed_ms::numeric / limit_ms))::int;
  end if;

  update public.answers
     set answered_at = now(),
         chosen_idx  = case when p_choice between 0 and 3 then p_choice end,
         is_correct  = ok,
         points      = pts
   where player_id = p.id and q_index = p.current_q;

  update public.questions
     set served = served + 1,
         correct_count = correct_count + ok::int,
         total_ms = total_ms + elapsed_ms
   where id = q.id;

  update public.duel_players
     set current_q   = current_q + 1,
         score       = score + pts,
         correct     = correct + ok::int,
         total_ms    = total_ms + elapsed_ms,
         finished_at = case when current_q + 1 >= 5 then now() end
   where id = p.id
  returning * into p;

  if p.finished_at is not null then
    perform public._touch_streak(uid);
    perform public._settle_duel(p_duel_id);
  end if;

  return json_build_object(
    'correct',     ok,
    'correct_idx', q.correct_idx,
    'points',      pts,
    'score',       p.score,
    'elapsed_ms',  elapsed_ms,
    'done',        p.finished_at is not null
  );
end $$;

-- Everything the result screen needs. Answers and explanations are only
-- revealed to a player who has finished.
create function public.get_duel(p_duel_id uuid) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  d public.duels;
  me public.duel_players;
  opp public.duel_players;
  review json;
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

  return json_build_object(
    'id',         d.id,
    'code',       root_code,
    'mode',       d.mode,
    'status',     d.status,
    'is_creator', me.seat = 1 and not me.is_replay,
    'me',         public._player_json(me),
    'opponent',   case when opp.id is null then null else public._player_json(opp) end,
    'review',     review
  );
end $$;

-- The signed-in player's profile, streak and college rank.
create function public.get_me() returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  r json;
begin
  select json_build_object(
           'id',           p.id,
           'name',         p.display_name,
           'rating',       p.rating,
           'games_played', p.games_played,
           'wins',         p.wins,
           'streak',       case when p.last_played_on >= public._today() - 1
                                then p.streak_current else 0 end,
           'streak_best',  p.streak_best,
           'played_today', coalesce(p.last_played_on = public._today(), false),
           'college_id',   p.college_id,
           'college',      c.name,
           'grad_year',    p.grad_year,
           'college_rank', case when p.college_id is null then null else
                             (select count(*) + 1 from public.profiles x
                               where x.college_id = p.college_id and x.rating > p.rating) end
         )
    into r
    from public.profiles p
    left join public.colleges c on c.id = p.college_id
   where p.id = uid;
  return r;
end $$;

create function public.update_profile(p_name text, p_college_id int default null, p_grad_year int default null)
returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  n text := btrim(p_name);
begin
  if n is null or char_length(n) not between 2 and 24 then
    raise exception 'Name must be 2 to 24 characters.';
  end if;
  if p_grad_year is not null and p_grad_year not between 2020 and 2035 then
    raise exception 'Pick a graduation year between 2020 and 2035.';
  end if;
  if p_college_id is not null and not exists (select 1 from public.colleges where id = p_college_id) then
    raise exception 'Unknown college.';
  end if;

  update public.profiles
     set display_name = n, college_id = p_college_id, grad_year = p_grad_year
   where id = uid;
  return public.get_me();
end $$;

-- Recent duels for the home screen, newest first.
create function public.my_duels(p_limit int default 10) returns json
language sql stable security definer set search_path = '' as $$
  select coalesce(json_agg(x order by x.created_at desc), '[]'::json)
  from (
    select d.id, d.mode, d.status, d.created_at,
           me.seat, me.is_replay,
           me.score, me.finished_at is not null as finished,
           me.rating_before, me.rating_after,
           op.display_name as opponent_name,
           o.score as opponent_score,
           o.finished_at is not null as opponent_finished
      from public.duel_players me
      join public.duels d on d.id = me.duel_id
      left join public.duel_players o on o.duel_id = d.id and o.id <> me.id
      left join public.profiles op on op.id = o.user_id
     where me.user_id = auth.uid()
     order by d.created_at desc
     limit least(greatest(p_limit, 1), 50)
  ) x
$$;


-- ---------------------------------------------------------------------
-- Permissions: clients may call only the API functions above.
-- ---------------------------------------------------------------------

revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function public.get_challenge(text) to anon, authenticated;
grant execute on function
  public.create_challenge(),
  public.join_challenge(text),
  public.challenge_from_duel(uuid),
  public.next_question(uuid),
  public.submit_answer(uuid, int, int),
  public.get_duel(uuid),
  public.get_me(),
  public.update_profile(text, int, int),
  public.my_duels(int)
to authenticated;
