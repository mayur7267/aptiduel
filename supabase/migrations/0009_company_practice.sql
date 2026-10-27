-- =====================================================================
-- AptiDuel · 0009_company_practice
-- Company practice: a Quick Match whose 5 questions all come from one
-- company's test pattern (TCS NQT, Infosys, Accenture or Wipro, as tagged
-- by 0008 and the seed). Recorded runs are built on general sets, so a
-- company match is always against a practice bot near your rating.
-- It is still a quick match: an unfinished one is resumed by either
-- button, and it counts towards quests and ratings the same way.
-- Adds functions only. Safe to run more than once.
-- =====================================================================

-- 2 quant + 2 reasoning + 1 verbal, all on the company's pattern.
create or replace function public._company_set(p_company text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  ids bigint[];
  sid bigint;
begin
  select array_agg(id order by random()) into ids
  from (
    (select id from public.questions
      where status = 'active' and section = 'quant' and p_company = any(company_tags)
      order by random() limit 2)
    union all
    (select id from public.questions
      where status = 'active' and section = 'reasoning' and p_company = any(company_tags)
      order by random() limit 2)
    union all
    (select id from public.questions
      where status = 'active' and section = 'verbal' and p_company = any(company_tags)
      order by random() limit 1)
  ) picked;

  if coalesce(array_length(ids, 1), 0) < 5 then
    raise exception 'There aren''t enough % questions yet.', p_company;
  end if;
  insert into public.duel_sets (question_ids) values (ids) returning id into sid;
  return sid;
end $$;

revoke execute on function public._company_set(text) from public, anon, authenticated;

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
      return json_build_object('duel_id', existing);
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

  insert into public.duels (code, mode, set_id, created_by)
  values (public._new_code(), 'quick', public._company_set(p_company), uid)
  returning * into d;
  perform public._bot_run(d.id, bot);

  insert into public.duel_players (duel_id, user_id, seat) values (d.id, uid, 2);
  return json_build_object('duel_id', d.id);
end $$;

revoke execute on function public.company_match(text) from public, anon;
grant execute on function public.company_match(text) to authenticated;
