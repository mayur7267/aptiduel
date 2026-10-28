-- =====================================================================
-- Apticks · 0010_audit_fixes
-- Fixes from the full audit (29 Oct 2026):
--  * Odd-one-out questions with two defensible answers are retired and
--    replaced with clean ones.
--  * Today's Daily Challenge set can't be shared or used as a Quick Match
--    opponent until it resets, so nobody sees the questions early.
--  * Deleting an account anonymises it ("Deleted player") instead of
--    deleting duels other players took part in. A deleted account's
--    leftover session can't recreate it.
--  * Player records are no longer readable directly; the app reads
--    players only through the API functions. Stray table rights for
--    guests are removed.
--  * A challenge between the same two players moves ratings at most once
--    a day, so a second account can't be used to farm wins.
--  * Two players finishing a live challenge at the same instant could
--    deadlock. Answers in one duel are now handled one at a time.
--  * A challenge link can be sent before playing; later friends are told
--    to wait until the challenger has played.
--  * Quick Match and company practice say when they resume an unfinished
--    match, and duels remember their company.
--  * New sets prefer questions the player hasn't answered yet.
--  * Names can't contain links, staff-sounding words, invisible
--    characters or abuse.
--  * Daily duels are marked complete, question stats are rebuilt from
--    real answers (test runs had skewed them), missing indexes are added,
--    and the leaderboard only works out weekly change for rows it shows.
-- Safe to run more than once.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Columns, indexes and table rights
-- ---------------------------------------------------------------------

alter table public.profiles add column if not exists deleted_at timestamptz;
alter table public.duels add column if not exists company text;

create index if not exists duels_created_by_idx on public.duels (created_by, created_at);
create index if not exists answers_question_idx on public.answers (question_id);
create index if not exists profiles_ranked_idx on public.profiles (rating desc)
  where last_played_on is not null and not is_bot and deleted_at is null;

drop policy if exists "profiles are public" on public.profiles;
revoke all on public.profiles from anon, authenticated;
revoke insert, update, delete, truncate, trigger, references on public.colleges from anon, authenticated;


-- ---------------------------------------------------------------------
-- Ambiguous odd-one-out questions
-- ---------------------------------------------------------------------

-- Retire numeric odd-one-out questions where an option other than the
-- answer also stands out: the only even (or odd) number, the only square,
-- cube, prime or multiple of 7.
with q as (
  select id, options[correct_idx + 1]::int as key, array(select o::int from unnest(options) o) as nums
    from public.questions
   where status = 'active' and topic = 'Odd One Out' and options[1] ~ '^\d+$'
), props as (
  select q.id, q.key, n, prop, has
    from q, unnest(q.nums) n,
         lateral (values
           ('even',   n % 2 = 0),
           ('square', sqrt(n) = floor(sqrt(n))),
           ('cube',   round(cbrt(n))::int ^ 3 = n),
           ('seven',  n % 7 = 0),
           ('prime',  n > 1 and not exists (
                        select 1 from generate_series(2, floor(sqrt(n))::int) d where n % d = 0))
         ) v(prop, has)
), lone as (
  select id, key, prop,
         case count(*) filter (where has)
           when 1 then (array_agg(n) filter (where has))[1]
           when 3 then (array_agg(n) filter (where not has))[1]
         end as n
    from props
   group by id, key, prop
)
update public.questions
   set status = 'retired'
 where id in (select id from lone where n is not null and n <> key);

-- Clean replacements, made by the generator's new check.
insert into public.questions
  (section, topic, difficulty, body, options, correct_idx, explanation, time_limit_s, template, figure, option_figures, variant)
values
  ('reasoning', 'Odd One Out', 1, 'Find the odd one out: 41, 29, 39, 67', array['67', '39', '29', '41'], 1, '67, 41, 29 are prime numbers. 39 is not (39 = 3 × 13).', 30, 'odd_one_out', null, null, null),
  ('reasoning', 'Odd One Out', 1, 'Find the odd one out: 73, 91, 67, 31', array['91', '73', '67', '31'], 0, '73, 67, 31 are prime numbers. 91 is not (91 = 7 × 13).', 30, 'odd_one_out', null, null, null),
  ('reasoning', 'Odd One Out', 1, 'Find the odd one out: 61, 49, 53, 83', array['53', '83', '61', '49'], 3, '83, 61, 53 are prime numbers. 49 is not (49 = 7 × 7).', 30, 'odd_one_out', null, null, null),
  ('reasoning', 'Odd One Out', 1, 'Find the odd one out: 73, 31, 47, 33', array['31', '73', '33', '47'], 2, '73, 47, 31 are prime numbers. 33 is not (33 = 3 × 11).', 30, 'odd_one_out', null, null, null),
  ('reasoning', 'Odd One Out', 1, 'Find the odd one out: 31, 67, 23, 33', array['23', '31', '33', '67'], 2, '31, 67, 23 are prime numbers. 33 is not (33 = 3 × 11).', 30, 'odd_one_out', null, null, null),
  ('reasoning', 'Odd One Out', 1, 'Find the odd one out: 512, 64, 729, 515', array['729', '512', '515', '64'], 2, '512, 729, 64 are perfect cubes. 515 is not.', 30, 'odd_one_out', null, null, null),
  ('reasoning', 'Odd One Out', 1, 'Find the odd one out: 344, 8, 512, 216', array['512', '8', '216', '344'], 3, '512, 216, 8 are perfect cubes. 344 is not.', 30, 'odd_one_out', null, null, null)
on conflict (body, (coalesce(variant, ''))) do nothing;


-- ---------------------------------------------------------------------
-- Deleted accounts
-- ---------------------------------------------------------------------

-- Keeps the player's duels, since other people took part in them, but
-- removes everything that identifies them.
create or replace function public._anonymize_player(p_user uuid) returns void
language sql security definer set search_path = '' as $$
  update public.profiles
     set display_name = 'Deleted player', college_id = null, grad_year = null, tagline = null,
         deleted_at = coalesce(deleted_at, now())
   where id = p_user;
$$;

create or replace function public._on_auth_user_deleted() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public._anonymize_player(old.id);
  return old;
end $$;

create or replace function public.delete_me() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in required' using errcode = '28000';
  end if;
  perform public._anonymize_player(auth.uid());
  delete from auth.users where id = auth.uid();
end $$;

create or replace function public._require_player() returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Sign in required' using errcode = '28000';
  end if;
  -- A deleted account's session can outlive it on another device.
  if exists (select 1 from public.profiles where id = uid and deleted_at is not null) then
    raise exception 'This account was deleted.' using errcode = '28000';
  end if;
  insert into public.profiles (id, display_name)
  values (uid, 'Player ' || lpad(floor(random() * 10000)::int::text, 4, '0'))
  on conflict (id) do nothing;
  return uid;
end $$;


-- ---------------------------------------------------------------------
-- Names
-- ---------------------------------------------------------------------

create or replace function public.update_profile(p_name text, p_college_id int default null, p_grad_year int default null)
returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  n text := btrim(p_name);
begin
  if n is null or char_length(n) not between 2 and 24 then
    raise exception 'Name must be 2 to 24 characters.';
  end if;
  -- Names show on leaderboards and shared challenge cards: no links,
  -- staff-sounding names, invisible characters or abuse.
  if n ~ '[[:cntrl:]\u200B-\u200D\u2060\uFEFF]'
     or n ~* '(https?://|www\.|\.(com|in|net|org|io|app)\M|@)'
     or n ~* '\m(admin|administrator|apticks|official|support|moderator|deleted player)\M'
     or n ~* '\m(fuck\w*|shit\w*|bitch\w*|bastard|asshole|dick|cunt|chutiya|madarchod|bhenchod|behenchod|bhosdi\w*|gandu|randi|lund|lavda|lauda)\M' then
    raise exception 'Please pick a different name.';
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


-- ---------------------------------------------------------------------
-- Leaderboard, profile and challenge page: skip deleted players
-- ---------------------------------------------------------------------

create or replace function public._week_delta(p_user uuid, p_since timestamptz) returns int
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(rating_after - rating_before), 0)::int
    from public.duel_players
   where user_id = p_user and not is_replay and rating_after is not null and finished_at >= p_since;
$$;

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

  -- Rank everyone, but only work out the weekly change for rows shown.
  with ranked as (
    select pr.id, pr.display_name, pr.rating, pr.grad_year, c.name as college,
           rank() over (order by pr.rating desc) as rnk
      from public.profiles pr
      left join public.colleges c on c.id = pr.college_id
     where pr.last_played_on is not null
       and not pr.is_bot
       and pr.deleted_at is null
       and (p_scope = 'india' or pr.college_id = my_college)
  ), shown as (
    select * from ranked order by rnk, display_name limit least(greatest(p_limit, 1), 100)
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
                                         'week_delta', public._week_delta(x.id, week_start),
                                         'is_me',      x.id = uid)
                                       order by x.rnk, x.display_name)
                                  from shown x),
                               '[]'::json),
           'me',      (select json_build_object(
                                'rank',       x.rnk,
                                'name',       x.display_name,
                                'rating',     x.rating,
                                'college',    x.college,
                                'grad_year',  x.grad_year,
                                'week_delta', public._week_delta(x.id, week_start),
                                'is_me',      true)
                         from ranked x where x.id = uid)
         ) into r;
  return r;
end $$;

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
                                 and x.last_played_on is not null
                                 and not x.is_bot and x.deleted_at is null) end,
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
    and pr.deleted_at is null
$$;


-- ---------------------------------------------------------------------
-- Settling duels
-- ---------------------------------------------------------------------

-- Once both players have finished, decide the winner and update Elo
-- ratings. Higher score wins; equal scores go to the faster player.
-- A replayed run (challenge copy) never changes the original player's
-- rating, so one challenge link can't be farmed. Two players move each
-- other's rating with a challenge at most once a day, so a second
-- account can't be used to farm wins either.
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

  if d.mode = 'challenge' and not p1.is_replay and exists (
       select 1
         from public.duel_players a
         join public.duel_players b on b.duel_id = a.duel_id and b.user_id <> a.user_id
         join public.duels x on x.id = a.duel_id
        where x.mode = 'challenge' and x.id <> p_duel_id
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

create or replace function public.submit_answer(p_duel_id uuid, p_q_index int, p_choice int default null)
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
  -- One answer at a time per duel. Without this, two players finishing a
  -- live challenge at the same instant could deadlock while settling it.
  perform 1 from public.duels where id = p_duel_id for update;

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
    -- A daily run has no opponent, so it is complete as soon as it ends.
    update public.duels set status = 'complete' where id = p_duel_id and mode = 'daily';
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


-- ---------------------------------------------------------------------
-- Challenges: keep today's daily set private, carry the company along
-- ---------------------------------------------------------------------

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

  -- Sharing today's daily set would show friends its answers before they
  -- play their own daily.
  if exists (select 1 from public.daily_sets where set_id = d.set_id and day >= public._today()) then
    raise exception 'You can challenge friends with this set after the daily resets at midnight.';
  end if;

  if d.mode = 'challenge' and me.seat = 1 then
    return json_build_object('code', (select code from public.duels where id = coalesce(d.parent_id, d.id)));
  end if;

  select * into made from public.duels
   where parent_id is null and mode = 'challenge' and created_by = uid and set_id = d.set_id;
  if found then
    return json_build_object('code', made.code);
  end if;

  insert into public.duels (code, mode, set_id, created_by, company)
  values (public._new_code(), 'challenge', d.set_id, uid, d.company)
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


-- ---------------------------------------------------------------------
-- Question sets: questions you haven't seen come first
-- ---------------------------------------------------------------------

-- 2 quant + 1 picture question + 1 other reasoning + 1 verbal. Falls
-- back to 2 text reasoning questions if there are no picture ones yet.
create or replace function public._new_set() returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  ids bigint[];
  sid bigint;
  seen bigint[];
begin
  -- Questions the caller has already answered go to the back of the queue.
  select coalesce(array_agg(distinct a.question_id), '{}') into seen
    from public.answers a
    join public.duel_players dp on dp.id = a.player_id
   where dp.user_id = auth.uid() and not dp.is_replay;

  select array_agg(id order by random()) into ids
  from (
    (select id from public.questions where status = 'active' and section = 'quant'
      order by id = any(seen), random() limit 2)
    union all
    (select id from (
       (select id, 0 as pri from public.questions
         where status = 'active' and section = 'reasoning' and option_figures is not null
         order by id = any(seen), random() limit 1)
       union all
       (select id, 1 as pri from public.questions
         where status = 'active' and section = 'reasoning' and option_figures is null
         order by id = any(seen), random() limit 2)
     ) r
     order by pri
     limit 2)
    union all
    (select id from public.questions where status = 'active' and section = 'verbal'
      order by id = any(seen), random() limit 1)
  ) picked;

  if coalesce(array_length(ids, 1), 0) < 5 then
    raise exception 'The question bank is empty. Load the seed first.';
  end if;

  insert into public.duel_sets (question_ids) values (ids) returning id into sid;
  return sid;
end $$;

-- 2 quant + 2 reasoning + 1 verbal, all on the company's pattern.
create or replace function public._company_set(p_company text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  ids bigint[];
  sid bigint;
  seen bigint[];
begin
  select coalesce(array_agg(distinct a.question_id), '{}') into seen
    from public.answers a
    join public.duel_players dp on dp.id = a.player_id
   where dp.user_id = auth.uid() and not dp.is_replay;

  select array_agg(id order by random()) into ids
  from (
    (select id from public.questions
      where status = 'active' and section = 'quant' and p_company = any(company_tags)
      order by id = any(seen), random() limit 2)
    union all
    (select id from public.questions
      where status = 'active' and section = 'reasoning' and p_company = any(company_tags)
      order by id = any(seen), random() limit 2)
    union all
    (select id from public.questions
      where status = 'active' and section = 'verbal' and p_company = any(company_tags)
      order by id = any(seen), random() limit 1)
  ) picked;

  if coalesce(array_length(ids, 1), 0) < 5 then
    raise exception 'There aren''t enough % questions yet.', p_company;
  end if;
  insert into public.duel_sets (question_ids) values (ids) returning id into sid;
  return sid;
end $$;


-- ---------------------------------------------------------------------
-- Quick Match and company practice
-- ---------------------------------------------------------------------

create or replace function public.quick_match() returns json
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
  -- One at a time per player, so a double tap (or a retried request)
  -- can't start two quick matches at once.
  perform pg_advisory_xact_lock(hashtext('quick match:' || uid::text));
  -- Finish an open quick match before starting another, so a bad run
  -- can't be dodged.
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

  select rating into my_rating from public.profiles where id = uid;

  select p.* into ghost
    from public.duel_players p
    join public.duels gd on gd.id = p.duel_id
    join public.profiles gp on gp.id = p.user_id
   where p.user_id <> uid
     and not gp.is_bot
     and gp.deleted_at is null
     and not p.is_replay
     and p.finished_at is not null
     and p.finished_at > now() - interval '60 days'
     and gd.mode <> 'daily'
     -- Never today's daily set: playing it early would spoil the daily.
     and not exists (select 1 from public.daily_sets ds
                      where ds.set_id = gd.set_id and ds.day >= public._today())
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
  return json_build_object('duel_id', d.id, 'resumed', false);
end $$;

create or replace function public.company_match(p_company text) returns json
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  my_rating int;
  existing uuid;
  existing_player uuid;
  bot uuid;
  d public.duels;
begin
  if not exists (select 1 from public.questions where p_company = any(company_tags)) then
    raise exception 'Unknown company.';
  end if;

  -- Same rules as quick_match: one at a time, finish an open quick match
  -- first, and a match left until its question ran out is forfeited.
  perform pg_advisory_xact_lock(hashtext('quick match:' || uid::text));
  select x.id, me.id into existing, existing_player
    from public.duels x
    join public.duel_players me on me.duel_id = x.id and me.user_id = uid
   where x.mode = 'quick' and not me.is_replay and me.finished_at is null
   order by x.created_at desc
   limit 1;
  if found then
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

  select rating into my_rating from public.profiles where id = uid;
  select id into bot
    from public.profiles
   where is_bot
   order by abs(rating - my_rating) + random() * 140
   limit 1;

  insert into public.duels (code, mode, set_id, created_by, company)
  values (public._new_code(), 'quick', public._company_set(p_company), uid, p_company)
  returning * into d;
  perform public._bot_run(d.id, bot);

  insert into public.duel_players (duel_id, user_id, seat) values (d.id, uid, 2);
  return json_build_object('duel_id', d.id, 'resumed', false);
end $$;


-- ---------------------------------------------------------------------
-- Reads: the duel's company
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

create or replace function public.my_duels(p_limit int default 10) returns json
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
-- Backfills
-- ---------------------------------------------------------------------

update public.duels d
   set status = 'complete'
 where d.mode = 'daily' and d.status = 'open'
   and exists (select 1 from public.duel_players p where p.duel_id = d.id and p.finished_at is not null);

-- Rebuild question stats from real players' answers. Test runs had
-- inflated them (and always picked the same option).
update public.questions set served = 0, correct_count = 0, total_ms = 0;
update public.questions q
   set served = s.n, correct_count = s.c, total_ms = s.ms
  from (select a.question_id,
               count(*) as n,
               count(*) filter (where a.is_correct) as c,
               sum(least((extract(epoch from (a.answered_at - a.sent_at)) * 1000)::bigint,
                         qq.time_limit_s * 1000)) as ms
          from public.answers a
          join public.duel_players dp on dp.id = a.player_id
          join public.questions qq on qq.id = a.question_id
         where not dp.is_replay and a.answered_at is not null
         group by a.question_id) s
 where s.question_id = q.id;


-- ---------------------------------------------------------------------
-- Permissions for the new helpers
-- ---------------------------------------------------------------------

revoke execute on function public._anonymize_player(uuid), public._week_delta(uuid, timestamptz)
  from public, anon, authenticated;
