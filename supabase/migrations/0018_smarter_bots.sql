-- =====================================================================
-- Apticks · 0018_smarter_bots
-- 50 more practice bots, rated about 1,010 to 1,990, and bots that play
-- like someone in particular instead of a coin weighted by rating.
--
-- Each bot gets a persona (bot_traits): a section it is strong in, one it
-- is weak in, and a style. Its tagline is now true to life: "Percentages
-- in their sleep" really is faster and better at quant.
--
--   steady     no quirks
--   speedster  answers fast, makes a few more slips
--   careful    takes its time, makes fewer slips
--   streaky    rides momentum: a right answer lifts the next, a miss hurts it
--   guesser    thinks a little less, never runs out the clock, and a lucky
--              guess lands now and then
--
-- Every run also has a good-or-bad day, hard questions hurt weaker bots
-- more than stronger ones, and strong bots no longer top out at 90%.
-- Bot ratings never change and bots stay off the leaderboards.
-- Run after 0017. Safe to run more than once.
-- =====================================================================

create table if not exists public.bot_traits (
  bot_id uuid primary key references public.profiles (id) on delete cascade,
  strong text check (strong in ('quant', 'reasoning', 'verbal')),
  weak   text check (weak   in ('quant', 'reasoning', 'verbal')),
  style  text not null default 'steady'
         check (style in ('steady', 'speedster', 'careful', 'streaky', 'guesser'))
);

-- Only the bot functions read this; the API never touches it.
alter table public.bot_traits enable row level security;
revoke all on public.bot_traits from public, anon, authenticated;


-- One statement: add the new bots, then give every bot without a persona
-- the one its tagline describes (the 48 older ones included).
with persona(n, tagline, strong, weak, style) as (
  values
    -- the 12 taglines the first bots already carry
    (null::int, 'Fast on percentages',      'quant',     'verbal',    'speedster'),
    (null,      'Never skips a question',   null,        null,        'guesser'),
    (null,      'Strong in reasoning',      'reasoning', 'quant',     'steady'),
    (null,      'Slow and steady',          null,        null,        'careful'),
    (null,      'Loves time and work',      'quant',     'verbal',    'steady'),
    (null,      'Guesses when stuck',       null,        null,        'guesser'),
    (null,      'Grammar first',            'verbal',    'quant',     'careful'),
    (null,      'Trains and clocks expert', 'quant',     'reasoning', 'steady'),
    (null,      'Practises every night',    null,        null,        'steady'),
    (null,      'Number series fan',        'reasoning', 'verbal',    'steady'),
    (null,      'Speed over accuracy',      null,        null,        'speedster'),
    (null,      'Hates leaving blanks',     null,        null,        'guesser'),
    -- 20 for the new bots, handed out in turn
    (1,  'Quant machine',                   'quant',     'verbal',    'steady'),
    (2,  'Syllogisms for breakfast',        'reasoning', 'quant',     'careful'),
    (3,  'Reads fast, answers faster',      'verbal',    'reasoning', 'speedster'),
    (4,  'Percentages in their sleep',      'quant',     'reasoning', 'speedster'),
    (5,  'Blood relations pro',             'reasoning', 'verbal',    'steady'),
    (6,  'Never rushes, rarely misses',     null,        null,        'careful'),
    (7,  'Big swings, big scores',          null,        null,        'streaky'),
    (8,  'Hot streaks, cold streaks',       null,        null,        'streaky'),
    (9,  'Always takes a shot',             null,        null,        'guesser'),
    (10, 'Verbal ace',                      'verbal',    'quant',     'steady'),
    (11, 'Seating-arrangement fan',         'reasoning', 'verbal',    'careful'),
    (12, 'Time, speed and distance geek',   'quant',     'verbal',    'careful'),
    (13, 'Interview prep in progress',      null,        null,        'steady'),
    (14, 'Beats the clock',                 null,        null,        'speedster'),
    (15, 'Checks every option twice',       null,        null,        'careful'),
    (16, 'Puzzles for fun',                 'reasoning', 'quant',     'streaky'),
    (17, 'Mental maths champ',              'quant',     'verbal',    'speedster'),
    (18, 'Comprehension king',              'verbal',    'reasoning', 'careful'),
    (19, 'Warming up for the coding round', null,        null,        'steady'),
    (20, 'Placement season grinder',        null,        null,        'steady')
),
new_bots as (
  insert into public.profiles (id, display_name, rating, is_bot, tagline)
  select gen_random_uuid(),
         b.name,
         1010 + (b.ord - 1) * 20,
         true,
         ps.tagline
    from unnest(array[
      'Aryan G.',     'Shreya M.',    'Nikhil P.',    'Tanya S.',     'Rishi K.',
      'Mansi D.',     'Parth R.',     'Kritika N.',   'Naman B.',     'Swati V.',
      'Vivek T.',     'Isha C.',      'Gaurav L.',    'Nandini H.',   'Mohit J.',
      'Aishwarya F.', 'Shivam A.',    'Radhika W.',   'Ankit E.',     'Kriti O.',
      'Rajat U.',     'Sanya Y.',     'Utkarsh Z.',   'Mahima Q.',    'Vedant I.',
      'Prerna G.',    'Jayant M.',    'Shruti P.',    'Ritvik S.',    'Aarushi K.',
      'Sahil D.',     'Anushka R.',   'Chirag N.',    'Jhanvi B.',    'Harshit V.',
      'Sonal T.',     'Lakshya C.',   'Tara L.',      'Madhav H.',    'Esha J.',
      'Dhruv F.',     'Palak A.',     'Kshitij W.',   'Mitali E.',    'Yuvraj O.',
      'Rhea U.',      'Zoya Y.',      'Imran Z.',     'Gurpreet Q.',  'Sarthak I.'
    ]) with ordinality as b(name, ord)
    join persona ps on ps.n = 1 + ((b.ord - 1) % 20)::int
   where not exists (
     select 1 from public.profiles p where p.is_bot and p.display_name = b.name)
  returning id, tagline
)
insert into public.bot_traits (bot_id, strong, weak, style)
select x.id, ps.strong, ps.weak, ps.style
  from (select id, tagline from new_bots
        union all
        select id, tagline from public.profiles where is_bot) x
  join persona ps on ps.tagline = x.tagline
on conflict (bot_id) do nothing;


-- Simulates a bot's run on a duel's questions and seats it as player 1,
-- as a recorded run (settling the duel never changes the bot's rating).
create or replace function public._bot_run(p_duel_id uuid, p_bot uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  b public.profiles;
  tr public.bot_traits;       -- empty for a bot without a persona: plain "steady"
  style text;
  ids bigint[];
  q public.questions;
  pid uuid;
  t timestamptz := now() - interval '15 minutes';
  base numeric;               -- chance of a right answer on a middling question
  pace numeric;               -- share of the timer a middling question takes
  form numeric := (random() - 0.5) * 0.14;  -- a good or bad day, for the whole run
  tilt numeric := 0;          -- streaky bots: momentum from the last answer
  p numeric;
  ok boolean;
  limit_ms int;
  ms int;
  pts int;
  v_score int := 0;
  v_correct int := 0;
  v_ms int := 0;
begin
  select * into b from public.profiles where id = p_bot and is_bot;
  select * into tr from public.bot_traits where bot_id = p_bot;
  style := coalesce(tr.style, 'steady');
  select s.question_ids into ids
    from public.duels d join public.duel_sets s on s.id = d.set_id
   where d.id = p_duel_id;

  -- Chance of a right answer: about 38% at 800, 63% at 1,250, 88% at 1,700
  -- and 94% at 2,000, so the top bots stay a step ahead.
  base := 0.30 + 0.66 / (1 + exp(-(b.rating - 1250) / 230.0));
  -- Share of the timer used: about 88% at 800, 80% at 1,000, 50% from 1,940.
  pace := least(0.92, greatest(0.50, 0.88 - (b.rating - 800) / 3000.0));

  insert into public.duel_players (duel_id, user_id, seat, is_replay, started_at)
  values (p_duel_id, b.id, 1, true, t)
  returning id into pid;

  for i in 1 .. array_length(ids, 1) loop
    select * into q from public.questions where id = ids[i];
    limit_ms := q.time_limit_s * 1000;

    p := base + form + tilt
         -- a section it knows, or one it dreads
         + case when q.section = tr.strong then 0.10
                when q.section = tr.weak   then -0.10
                else 0 end
         -- harder questions cost the weaker bots more than the stronger ones
         - 0.09 * (q.difficulty - 2) * (1.25 - base)
         + case style when 'speedster' then -0.04 when 'careful' then 0.04 when 'guesser' then -0.10 else 0 end;
    p := least(0.97, greatest(0.05, p));
    ok := random() < p;
    -- a guesser thinks a little less but always takes a shot, and one in
    -- five lands: about as strong as a steady bot, never stuck on the clock
    if not ok and style = 'guesser' then
      ok := random() < 0.20;
    end if;

    if not ok and style <> 'guesser' and random() < 0.2 then
      ms := limit_ms; -- stuck, ran out of time
    else
      -- harder questions take longer; speedsters rush, careful bots check
      ms := (limit_ms * least(0.97, greatest(0.25,
              pace * (1 + 0.15 * (q.difficulty - 2))
                   * case style when 'speedster' then 0.75 when 'careful' then 1.2 else 1 end
              + (random() - 0.5) * 0.3)))::int;
      ms := least(limit_ms - 500, greatest(9000, ms)); -- time to read the question
    end if;
    pts := case when ok then 100 + round(50 * (1 - ms::numeric / limit_ms))::int else 0 end;

    if style = 'streaky' then
      tilt := case when ok then least(tilt + 0.04, 0.10) else greatest(tilt - 0.06, -0.12) end;
    end if;

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

revoke execute on function public._bot_run(uuid, uuid) from public, anon, authenticated;
