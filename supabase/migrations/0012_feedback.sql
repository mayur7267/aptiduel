-- =====================================================================
-- Apticks · 0012_feedback
-- Players can report a problem, suggest a feature or flag a question,
-- from the website and the app. Each one is kept in public.feedback and
-- emailed to the team by the feedback-mail Edge Function
-- (supabase/functions/feedback-mail), which a trigger calls through
-- pg_net with nothing but the new row's id.
-- Safe to run more than once.
-- =====================================================================

create extension if not exists pg_net with schema extensions;

create table if not exists public.feedback (
  id          bigint generated always as identity primary key,
  user_id     uuid references auth.users (id) on delete set null,
  kind        text not null check (kind in ('bug', 'idea', 'question')),
  message     text not null check (char_length(message) between 3 and 2000),
  email       text,                          -- to reply to, if they gave one
  platform    text not null check (platform in ('web', 'ios', 'android')),
  context     jsonb not null default '{}',   -- page, app version, device, the question…
  player      jsonb not null default '{}',   -- name, rating and college when sent
  created_at  timestamptz not null default now(),
  emailed_at  timestamptz                    -- set by feedback-mail once sent
);

create index if not exists feedback_user_idx on public.feedback (user_id, created_at desc);

-- Only the database functions (and the mailer, with the service role) touch it.
alter table public.feedback enable row level security;
revoke all on public.feedback from anon, authenticated;

create or replace function public.submit_feedback(
  p_kind text,
  p_message text,
  p_email text default null,
  p_platform text default 'web',
  p_context jsonb default '{}'
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := public._require_player();
  msg text := btrim(coalesce(p_message, ''));
  mail text := nullif(btrim(coalesce(p_email, '')), '');
  ctx jsonb := coalesce(p_context, '{}'::jsonb);
  who jsonb;
begin
  if p_kind is null or p_kind not in ('bug', 'idea', 'question') then
    raise exception 'Pick what this is about.';
  end if;
  if char_length(msg) < 3 then
    raise exception 'Tell us a little more.';
  end if;
  if char_length(msg) > 2000 then
    raise exception 'That''s a bit long. Keep it under 2,000 characters.';
  end if;
  if mail is not null and (char_length(mail) > 254 or mail !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') then
    raise exception 'That email doesn''t look right.';
  end if;
  if p_platform is null or p_platform not in ('web', 'ios', 'android') then
    raise exception 'Unknown platform.';
  end if;
  if jsonb_typeof(ctx) <> 'object' or octet_length(ctx::text) > 4000 then
    ctx := '{}'::jsonb;
  end if;
  -- A few at a time is plenty, and keeps the inbox safe from floods.
  if (select count(*) from public.feedback where user_id = uid and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'Thanks, that''s a lot at once! Try again in a little while.';
  end if;

  select jsonb_build_object('name', p.display_name, 'rating', p.rating, 'games', p.games_played, 'college', c.name)
    into who
    from public.profiles p
    left join public.colleges c on c.id = p.college_id
   where p.id = uid;

  insert into public.feedback (user_id, kind, message, email, platform, context, player)
  values (uid, p_kind, msg, mail, p_platform, ctx, coalesce(who, '{}'::jsonb));
end $$;

revoke all on function public.submit_feedback(text, text, text, text, jsonb) from public, anon;
grant execute on function public.submit_feedback(text, text, text, text, jsonb) to authenticated;

-- Hands each new row to the mailer. The mailer reads the row itself, so
-- the call carries only the id; a failure here never blocks the feedback.
create or replace function public._feedback_mail() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  begin
    perform net.http_post(
      url := 'https://wqkmpltgbtmgrxfdczmi.supabase.co/functions/v1/feedback-mail',
      body := jsonb_build_object('id', new.id),
      headers := '{"Content-Type": "application/json"}'::jsonb
    );
  exception when others then
    raise warning 'feedback-mail not called: %', sqlerrm;
  end;
  return new;
end $$;

revoke all on function public._feedback_mail() from public, anon, authenticated;

drop trigger if exists feedback_mail on public.feedback;
create trigger feedback_mail
  after insert on public.feedback
  for each row execute function public._feedback_mail();
