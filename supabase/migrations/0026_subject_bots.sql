-- =====================================================================
-- Apticks · 0026_subject_bots
-- Bots for each subject, and Quick Match keeps to the subject you tapped.
--
-- 1. Quick Match resumed your last unfinished quick match whatever its
--    subject, so tapping Coding could drop you back into an Aptitude
--    run. Now it resumes only a run in the subject you tapped; an
--    unfinished run in another subject ends as it stands (unopened
--    questions score 0, as when the clock runs out), so a bad run still
--    can't be dodged.
--
-- 2. 50 Coding bots and 50 English bots, each with its own rating and a
--    record of games in its subject. A Coding match with no recording
--    to race finds a Coding bot, an English match an English bot, and
--    Aptitude keeps the 98 bots it has. Like every bot, they're tagged
--    in the app, never ranked, and their rating never changes.
--
-- Safe to run more than once.
-- =====================================================================

-- A bot's rating in a subject is its rating there, when it has one.
create or replace function public._rating(p_user uuid, p_subject text) returns int
language sql stable security definer set search_path = '' as $$
  select case when p_subject = 'aptitude' then p.rating
              when p.is_bot then coalesce(r.rating, p.rating)
              else coalesce(r.rating, 1000) end
    from public.profiles p
    left join public.subject_ratings r on r.user_id = p.id and r.subject = p_subject
   where p.id = p_user
$$;

-- The bots ------------------------------------------------------------------

-- One statement, no temporary table (the SQL editor doesn't keep one
-- between statements). Each subject's bots spread from about 800 to
-- about 1,980, a step of 24 apart in a shuffled order (37 and 50 share
-- no factor, so every step is used once), with a few points either way.
-- Wins follow the rating: about 30% at 800, about 75% at 2,000. Games
-- and wins are fixed per name, and a name that's already a bot is
-- skipped, so running this again changes nothing.
with b as (
    select 'coding' as subject, c.ord, c.name,
           (array[
             'Recursion before breakfast', 'Off-by-one survivor', 'Dry-runs every loop',
             'Pointers make sense to me', 'Big-O first, code later', 'Reads code like a novel',
             'Debugs in my head', 'Arrays and strings fan', 'Never trusts an edge case',
             'Traces every variable', 'Loves a tricky output question', 'OOP all the way'
           ])[1 + ((c.ord - 1) % 12)::int] as tagline
      from unnest(array[
        'Abhinav S.', 'Aakriti S.', 'Adarsh P.', 'Anvi R.', 'Advait K.', 'Bhumika J.', 'Ajay M.', 'Charvi N.',
        'Akshay D.', 'Deepika M.', 'Alok T.', 'Garima T.', 'Amaan H.', 'Ira K.', 'Amit V.', 'Juhi P.',
        'Aniket G.', 'Khushi D.', 'Anirudh B.', 'Mehak A.', 'Arnav C.', 'Muskan G.', 'Ashwin L.', 'Navya B.',
        'Atharva N.', 'Niharika V.', 'Ayush P.', 'Payal S.', 'Chaitanya R.', 'Rashi M.', 'Darshan M.', 'Saanvi K.',
        'Devansh K.', 'Shivani R.', 'Gautam N.', 'Srishti P.', 'Hardik B.', 'Tanisha J.', 'Ishaan D.', 'Trisha C.',
        'Kartik P.', 'Urvi L.', 'Keshav R.', 'Vidhi N.', 'Mayank T.', 'Keerthana R.', 'Mihir A.', 'Nivedita S.',
        'Neel K.', 'Sanjana T.'
      ]) with ordinality as c(name, ord)
    union all
    select 'english', e.ord, e.name,
           (array[
             'Idioms are my thing', 'Spots the error first', 'Reads the whole sentence',
             'Synonyms in my sleep', 'Grammar police, off duty', 'Para jumbles fan',
             'Active voice, always', 'Never misspells', 'Reads before guessing',
             'Phrasal verbs, sorted', 'Fast on fill in the blanks', 'Collects new words'
           ])[1 + ((e.ord - 1) % 12)::int]
      from unnest(array[
        'Nitin M.', 'Aparna K.', 'Pratik D.', 'Bhavana R.', 'Rachit G.', 'Chhavi S.', 'Rohit P.', 'Damini P.',
        'Sagar J.', 'Ekta M.', 'Sandeep R.', 'Gayatri N.', 'Saurabh N.', 'Harini S.', 'Shaurya B.', 'Jasleen K.',
        'Shubham K.', 'Kajal T.', 'Soham D.', 'Kanika B.', 'Tanmay R.', 'Ojasvi R.', 'Tushar G.', 'Komal D.',
        'Uday S.', 'Madhuri P.', 'Vaibhav M.', 'Mrunal K.', 'Vinay K.', 'Nupur S.', 'Yatin R.', 'Pihu G.',
        'Arpit H.', 'Rupal M.', 'Deepak S.', 'Ruchi A.', 'Hemant J.', 'Shalini V.', 'Jatin S.', 'Shraddha J.',
        'Manish G.', 'Sukriti N.', 'Nachiket V.', 'Tanu B.', 'Pranjal S.', 'Unnati R.', 'Rajesh K.', 'Vaishnavi S.',
        'Ansh J.', 'Yamini D.'
      ]) with ordinality as e(name, ord)
), n0 as (
  select b.subject, b.name, b.tagline,
         (800 + ((b.ord * 37) % 50) * 24 + (abs(hashtext(b.name)::bigint) % 15) - 7)::int as rating,
         (20 + abs(hashtext(b.name || ' games')::bigint) % 260)::int as games,
         (array['steady', 'speedster', 'careful', 'streaky', 'guesser'])[1 + b.ord % 5] as style
    from b
), n as (
  select n0.*,
         round(n0.games * least(0.8, greatest(0.25,
           0.30 + (n0.rating - 800) / 2700.0 + ((abs(hashtext(n0.name || ' wins')::bigint) % 11) - 5) / 100.0)))::int as wins
    from n0
), added as (
  insert into public.profiles (id, display_name, rating, games_played, wins, is_bot, tagline, created_at)
  select gen_random_uuid(), n.name, n.rating, n.games, n.wins, true, n.tagline,
         now() - make_interval(days => (20 + abs(hashtext(n.name || ' joined')::bigint) % 60)::int)
    from n
   where not exists (select 1 from public.profiles p where p.is_bot and p.display_name = n.name)
  returning id, display_name
), bots as (
  -- The bots just added, and any added by an earlier run.
  select id, display_name from added
  union all
  select id, display_name from public.profiles where is_bot
), ratings as (
  insert into public.subject_ratings (user_id, subject, rating, games, wins)
  select bots.id, n.subject, n.rating, n.games, n.wins
    from n join bots on bots.display_name = n.name
  on conflict (user_id, subject) do nothing
)
-- A playing style; every question in a subject is one section, so no
-- strong or weak section.
insert into public.bot_traits (bot_id, style)
select bots.id, n.style
  from n join bots on bots.display_name = n.name
on conflict (bot_id) do nothing;

-- Quick Match ---------------------------------------------------------------

-- quick_match (0024) with the two changes above.
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

notify pgrst, 'reload schema';
