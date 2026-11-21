-- 0028: 0027's rule for the plain college list ("the colleges in play")
-- looked players up in profiles, which players can't read, so that list
-- failed with "permission denied for table profiles". Each college now
-- keeps an in_play flag, set when a player picks it, and the rule reads that.

alter table public.colleges add column if not exists in_play boolean not null default false;

update public.colleges c set in_play = true
where not c.in_play and exists (select 1 from public.profiles p where p.college_id = c.id);

create or replace function public.mark_college_in_play() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.college_id is not null then
    update public.colleges set in_play = true where id = new.college_id and not in_play;
  end if;
  return new;
end $$;
revoke execute on function public.mark_college_in_play() from public, anon, authenticated;

drop trigger if exists profiles_college_in_play on public.profiles;
create trigger profiles_college_in_play after insert or update of college_id on public.profiles
  for each row execute function public.mark_college_in_play();

drop policy if exists "colleges in play are public" on public.colleges;
create policy "colleges in play are public" on public.colleges
  for select to anon, authenticated
  using (source = 'apticks' or in_play);
