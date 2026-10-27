-- =====================================================================
-- AptiDuel · 0007_stale_quick_match
-- Found in QA: leaving a quick match mid-question and pressing Quick
-- Match later resumed the old match, whose question had already run out,
-- so it skipped straight to question 2.
--
-- Now, if you left and the open question's time is up, that run is over:
-- the rest of it counts as unanswered (so a bad run still can't be
-- dodged), and you get a fresh match. A match whose clock is still
-- running is resumed as before.
-- Safe to run more than once.
-- =====================================================================

-- Ends a player's unfinished run: every question still open or unseen
-- counts as wrong and used the whole timer. Then settles the duel.
create or replace function public._forfeit_run(p_player uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  p public.duel_players;
  ids bigint[];
  left_ms int;
begin
  select * into p from public.duel_players where id = p_player and finished_at is null for update;
  if not found then
    return;
  end if;
  select s.question_ids into ids
    from public.duels d join public.duel_sets s on s.id = d.set_id
   where d.id = p.duel_id;

  -- The question that ran out.
  update public.answers a
     set answered_at = a.sent_at + make_interval(secs => q.time_limit_s),
         is_correct  = false,
         points      = 0
    from public.questions q
   where q.id = a.question_id and a.player_id = p.id and a.answered_at is null;

  -- Questions never opened, so the review still lists all five.
  insert into public.answers (player_id, q_index, question_id, sent_at, answered_at, is_correct, points)
  select p.id, i - 1, ids[i], now() - make_interval(secs => q.time_limit_s), now(), false, 0
    from generate_subscripts(ids, 1) as i
    join public.questions q on q.id = ids[i]
   where i - 1 >= p.current_q
  on conflict (player_id, q_index) do nothing;

  select coalesce(sum(q.time_limit_s * 1000), 0) into left_ms
    from public.answers a join public.questions q on q.id = a.question_id
   where a.player_id = p.id and a.q_index >= p.current_q;

  update public.duel_players
     set current_q   = array_length(ids, 1),
         total_ms    = total_ms + left_ms,
         finished_at = now()
   where id = p.id;

  perform public._settle_duel(p.duel_id);
end $$;

revoke execute on function public._forfeit_run(uuid) from public, anon, authenticated;

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
  -- can't start two quick matchs at once.
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
      return json_build_object('duel_id', existing);
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
