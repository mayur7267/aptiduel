-- =====================================================================
-- AptiDuel · 0004_bot_pace
-- Bots answered too quickly to feel human. They now take at least 9
-- seconds to read a question, use most of the timer at lower ratings,
-- and sometimes run out the clock on questions they get wrong.
-- Safe to run more than once.
-- =====================================================================

create or replace function public._bot_run(p_duel_id uuid, p_bot uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  b public.profiles;
  ids bigint[];
  q public.questions;
  pid uuid;
  t timestamptz := now() - interval '15 minutes';
  skill numeric;
  pace numeric;
  ok boolean;
  limit_ms int;
  ms int;
  pts int;
  v_score int := 0;
  v_correct int := 0;
  v_ms int := 0;
begin
  select * into b from public.profiles where id = p_bot and is_bot;
  select s.question_ids into ids
    from public.duels d join public.duel_sets s on s.id = d.set_id
   where d.id = p_duel_id;

  -- Chance of a correct answer: about 35% at 800, 90% at 1700.
  skill := least(0.92, greatest(0.30, 0.35 + (b.rating - 800) / 1640.0));
  -- Share of the timer used: about 88% at 800, 80% at 1000, 55% at 1800.
  pace := least(0.92, greatest(0.50, 0.88 - (b.rating - 800) / 3000.0));

  insert into public.duel_players (duel_id, user_id, seat, is_replay, started_at)
  values (p_duel_id, b.id, 1, true, t)
  returning id into pid;

  for i in 1 .. array_length(ids, 1) loop
    select * into q from public.questions where id = ids[i];
    limit_ms := q.time_limit_s * 1000;
    ok := random() < skill - 0.08 * (q.difficulty - 2);

    if not ok and random() < 0.2 then
      ms := limit_ms; -- stuck, ran out of time
    else
      ms := (limit_ms * least(0.97, greatest(0.40, pace + (random() - 0.5) * 0.3)))::int;
      ms := least(limit_ms - 500, greatest(9000, ms)); -- time to read the question
    end if;
    pts := case when ok then 100 + round(50 * (1 - ms::numeric / limit_ms))::int else 0 end;

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
