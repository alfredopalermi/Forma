-- Run this once in the Supabase SQL editor (Database > SQL Editor > New query).
-- The star rating (1-5) was localStorage-only too, same as votes were
-- before today's fix - every visitor saw only their own private rating,
-- never a real average. Same design as votes: anonymous-friendly voting
-- via a per-browser id that gets swapped for the real account id when
-- logged in (see supabase_votes_migration.sql for why).

alter table public.tools
  add column if not exists rating_sum integer not null default 0,
  add column if not exists rating_count integer not null default 0;

create table if not exists public.tool_ratings (
  tool_slug text not null references public.tools(slug) on delete cascade,
  voter_id text not null,
  rating smallint not null check (rating between 1 and 5),
  created_at timestamptz not null default now(),
  primary key (tool_slug, voter_id)
);

alter table public.tool_ratings enable row level security;

drop policy if exists "Anyone can view ratings" on public.tool_ratings;
create policy "Anyone can view ratings" on public.tool_ratings
  for select to anon, authenticated using (true);

drop policy if exists "Anyone can rate" on public.tool_ratings;
create policy "Anyone can rate" on public.tool_ratings
  for insert to anon, authenticated with check (true);

drop policy if exists "Anyone can change their own rating" on public.tool_ratings;
create policy "Anyone can change their own rating" on public.tool_ratings
  for update to anon, authenticated using (true) with check (true);

drop policy if exists "Anyone can remove their own rating" on public.tool_ratings;
create policy "Anyone can remove their own rating" on public.tool_ratings
  for delete to anon, authenticated using (true);

create or replace function public.sync_tool_rating_agg() returns trigger as $$
begin
  if (tg_op = 'INSERT') then
    update public.tools set rating_sum = rating_sum + new.rating, rating_count = rating_count + 1 where slug = new.tool_slug;
    return new;
  elsif (tg_op = 'UPDATE') then
    update public.tools set rating_sum = rating_sum - old.rating + new.rating where slug = new.tool_slug;
    return new;
  elsif (tg_op = 'DELETE') then
    update public.tools set rating_sum = greatest(0, rating_sum - old.rating), rating_count = greatest(0, rating_count - 1) where slug = old.tool_slug;
    return old;
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_sync_tool_rating_agg on public.tool_ratings;
create trigger trg_sync_tool_rating_agg
  after insert or update or delete on public.tool_ratings
  for each row execute function public.sync_tool_rating_agg();
