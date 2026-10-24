-- =====================================================================
-- AptiDuel · 0005_visual
-- Picture questions. A question can carry an SVG figure, and its four
-- options can be SVG figures instead of text. Every new duel set now
-- includes one picture question when the bank has any.
-- Safe to run more than once. Load supabase/seed.sql after this.
-- =====================================================================

alter table public.questions add column if not exists figure text;
alter table public.questions add column if not exists option_figures text[];
-- Picture questions share wording ("Which figure comes next?"), so the
-- seed tells them apart with a fingerprint of their figures.
alter table public.questions add column if not exists variant text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'questions_option_figures_check') then
    alter table public.questions add constraint questions_option_figures_check
      check (option_figures is null or array_length(option_figures, 1) = 4);
  end if;
end $$;

alter table public.questions drop constraint if exists questions_body_key;
create unique index if not exists questions_body_variant_key
  on public.questions (body, (coalesce(variant, '')));


-- 2 quant + 1 picture question + 1 other reasoning + 1 verbal. Falls
-- back to 2 text reasoning questions if there are no picture ones yet.
create or replace function public._new_set() returns bigint
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
    (select id from (
       (select id, 0 as pri from public.questions
         where status = 'active' and section = 'reasoning' and option_figures is not null
         order by random() limit 1)
       union all
       (select id, 1 as pri from public.questions
         where status = 'active' and section = 'reasoning' and option_figures is null
         order by random() limit 2)
     ) r
     order by pri
     limit 2)
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


-- next_question: now sends the figures too (never the answer).
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


-- get_duel: the answer review includes the figures.
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
    'review',            review,
    'daily',             daily
  );
end $$;

revoke execute on function public._new_set() from public, anon, authenticated;
