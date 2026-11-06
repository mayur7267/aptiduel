-- =====================================================================
-- Apticks · 0017_metrics
-- The pilot's numbers, straight from the game tables: no analytics SDK,
-- nothing new collected. Everything lives in a private `metrics` schema
-- that the API never exposes, so only the team can read it (SQL editor,
-- or the service role). Bots and replay copies are left out throughout.
--
--   select * from metrics.summary;     -- the funnel, all time and last 14 days
--   select * from metrics.retention;   -- next-day and day-7 return, by week
--   select * from metrics.daily;       -- signups, active players, games per day
--   select * from metrics.invites;     -- challenge links made and joined, by week
--   select * from metrics.colleges;    -- one row per campus
--
-- "Played" means finished at least one game. Days are IST dates.
-- Run after 0016. Safe to run more than once.
-- =====================================================================

create schema if not exists metrics;
revoke all on schema metrics from public, anon, authenticated;

-- Every finished game by a real player, one row each (replay copies of a
-- challenger's run are not games anyone played).
create or replace view metrics.plays as
select dp.user_id,
       dp.duel_id,
       d.mode,
       (dp.finished_at at time zone 'Asia/Kolkata')::date as played_on
  from public.duel_players dp
  join public.duels d on d.id = dp.duel_id
  join public.profiles p on p.id = dp.user_id and not p.is_bot
 where not dp.is_replay
   and dp.finished_at is not null;

create or replace view metrics.play_days as
select distinct user_id, played_on from metrics.plays;

-- One row per real player: when they arrived, whether they played, and
-- whether a friend's invite is what brought them in or what they sent.
create or replace view metrics.player_facts as
with first_seat as (
  -- how each player's very first duel started: accepting someone's
  -- challenge link or live room puts you in seat 2 of their duel
  select distinct on (dp.user_id)
         dp.user_id,
         (dp.seat = 2 and d.mode in ('challenge', 'live') and d.created_by <> dp.user_id) as via_invite
    from public.duel_players dp
    join public.duels d on d.id = dp.duel_id
   where not dp.is_replay
   order by dp.user_id, dp.started_at
)
select p.id as user_id,
       (p.created_at at time zone 'Asia/Kolkata')::date as signed_up_on,
       p.college_id,
       c.name as college,
       (select min(pd.played_on) from metrics.play_days pd where pd.user_id = p.id) as first_play,
       (select count(*) from metrics.play_days pd where pd.user_id = p.id) as days_played,
       coalesce(fs.via_invite, false) as via_invite,
       exists (
         select 1
           from public.duels xd
           join public.duel_players j on j.duel_id = xd.id and j.seat = 2
           join public.profiles jp on jp.id = j.user_id and not jp.is_bot
          where xd.created_by = p.id
            and xd.mode in ('challenge', 'live')
            and j.user_id <> p.id
       ) as invited_a_friend
  from public.profiles p
  left join public.colleges c on c.id = p.college_id
  left join first_seat fs on fs.user_id = p.id
 where not p.is_bot;

-- The funnel: how many guests become players, stick around and invite.
create or replace view metrics.summary as
select s.scope,
       count(*) as guests,
       count(*) filter (where f.first_play is not null) as played,
       round(100.0 * count(*) filter (where f.first_play is not null) / nullif(count(*), 0), 1) as played_pct,
       count(*) filter (where f.college_id is not null) as chose_college,
       count(*) filter (where f.days_played >= 2) as played_on_2_days,
       count(*) filter (where f.invited_a_friend) as invited_a_friend,
       count(*) filter (where f.via_invite) as came_from_an_invite
  from metrics.player_facts f
  join (values ('all time', date '1900-01-01'),
               ('last 14 days', (now() at time zone 'Asia/Kolkata')::date - 13)) as s(scope, since)
    on f.signed_up_on >= s.since
 group by s.scope;

-- Return rate by the week a player first played. Day 1 is the next IST
-- day; day 7 is any play 6 to 8 days later, so a missed evening is not a
-- lost player. A player counts only once that window has fully passed.
create or replace view metrics.retention as
with t as (select (now() at time zone 'Asia/Kolkata')::date as today),
p as (
  select f.user_id, f.first_play, f.via_invite,
         exists (select 1 from metrics.play_days d
                  where d.user_id = f.user_id and d.played_on = f.first_play + 1) as back_d1,
         exists (select 1 from metrics.play_days d
                  where d.user_id = f.user_id and d.played_on between f.first_play + 6 and f.first_play + 8) as back_d7
    from metrics.player_facts f
   where f.first_play is not null
)
select date_trunc('week', p.first_play)::date as week_of,
       count(*) as players,
       count(*) filter (where p.via_invite) as came_from_an_invite,
       count(*) filter (where p.first_play + 1 < t.today) as d1_measured,
       count(*) filter (where p.first_play + 1 < t.today and p.back_d1) as d1_back,
       round(100.0 * count(*) filter (where p.first_play + 1 < t.today and p.back_d1)
             / nullif(count(*) filter (where p.first_play + 1 < t.today), 0), 1) as d1_pct,
       count(*) filter (where p.first_play + 8 < t.today) as d7_measured,
       count(*) filter (where p.first_play + 8 < t.today and p.back_d7) as d7_back,
       round(100.0 * count(*) filter (where p.first_play + 8 < t.today and p.back_d7)
             / nullif(count(*) filter (where p.first_play + 8 < t.today), 0), 1) as d7_pct
  from p cross join t
 group by 1;

-- The last 60 days, one row each.
create or replace view metrics.daily as
with days as (
  select generate_series((now() at time zone 'Asia/Kolkata')::date - 59,
                         (now() at time zone 'Asia/Kolkata')::date,
                         interval '1 day')::date as day
)
select d.day,
       (select count(*) from metrics.player_facts f where f.signed_up_on = d.day) as signups,
       (select count(*) from metrics.player_facts f where f.first_play = d.day) as new_players,
       (select count(*) from metrics.play_days pd where pd.played_on = d.day) as active_players,
       (select count(*) from metrics.play_days pd
          join metrics.player_facts f on f.user_id = pd.user_id
         where pd.played_on = d.day and f.first_play < d.day) as returning_players,
       (select count(*) from metrics.plays p where p.played_on = d.day) as games
  from days d;

-- Challenge links and live rooms, by the week they were made: how many a
-- real friend (not a bot) joined, and how many friends that was.
create or replace view metrics.invites as
with links as (
  select xd.id,
         (xd.created_at at time zone 'Asia/Kolkata')::date as made_on,
         (select count(distinct j.user_id)
            from public.duels x
            join public.duel_players j on j.duel_id = x.id and j.seat = 2
            join public.profiles jp on jp.id = j.user_id and not jp.is_bot
           where (x.id = xd.id or x.parent_id = xd.id)
             and j.user_id <> xd.created_by) as friends
    from public.duels xd
    join public.profiles cp on cp.id = xd.created_by and not cp.is_bot
   where xd.mode in ('challenge', 'live')
     and xd.parent_id is null
)
select date_trunc('week', made_on)::date as week_of,
       count(*) as links_made,
       count(*) filter (where friends > 0) as links_joined,
       round(100.0 * count(*) filter (where friends > 0) / nullif(count(*), 0), 1) as joined_pct,
       coalesce(sum(friends), 0) as friends_joined
  from links
 group by 1;

-- One row per campus with at least one player: sign-ups, who actually
-- played, who was active this week, and the average rating of its top ten.
create or replace view metrics.colleges as
with ranked as (
  select p.college_id, p.rating,
         row_number() over (partition by p.college_id order by p.rating desc) as place
    from public.profiles p
   where not p.is_bot and p.deleted_at is null and p.college_id is not null and p.games_played > 0
),
top10 as (
  select college_id, round(avg(rating)) as top10_avg_rating
    from ranked where place <= 10 group by college_id
)
select f.college,
       count(*) as players,
       count(*) filter (where f.first_play is not null) as played,
       count(*) filter (where exists (
         select 1 from metrics.play_days pd
          where pd.user_id = f.user_id
            and pd.played_on >= (now() at time zone 'Asia/Kolkata')::date - 6)) as active_last_7_days,
       count(*) filter (where f.via_invite) as came_from_an_invite,
       max(t.top10_avg_rating) as top10_avg_rating
  from metrics.player_facts f
  left join top10 t on t.college_id = f.college_id
 where f.college_id is not null
 group by f.college
 order by players desc;

-- Team only: the API's roles get nothing here.
revoke all on all tables in schema metrics from public, anon, authenticated;
