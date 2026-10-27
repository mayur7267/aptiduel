-- =====================================================================
-- AptiDuel · 0008_company_tags
-- Each question now carries the company test patterns its topic belongs
-- to (TCS NQT, Infosys, Accenture, Wipro), set by supabase/seed.sql from
-- their published aptitude syllabuses. next_question and the answer
-- review send them, so players see which tests a topic shows up on.
-- Safe to run more than once. Load supabase/seed.sql after this.
-- =====================================================================

create or replace function public.next_question(p_duel_id uuid) returns json
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
    'done',           false,
    'q_index',        p.current_q,
    'total',          5,
    'section',        q.section,
    'topic',          q.topic,
    'companies',      q.company_tags,
    'difficulty',     q.difficulty,
    'body',           q.body,
    'figure',         q.figure,
    'options',        q.options,
    'option_figures', q.option_figures,
    'time_limit_ms',  q.time_limit_s * 1000,
    'remaining_ms',   greatest(0, q.time_limit_s * 1000 - elapsed_ms),
    'score',          p.score
  );
end $$;

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
