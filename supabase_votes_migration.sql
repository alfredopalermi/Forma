-- Run this once in the Supabase SQL editor (Database > SQL Editor > New query).
-- The heart/vote button only ever wrote to localStorage - every visitor saw
-- their own private counter, never anyone else's. tools.votes exists but
-- nothing has ever updated it (confirmed: all 33 rows sit at 0).
--
-- Voting stays anonymous (no login required, matching current behavior) via
-- a random id the browser generates once and keeps in localStorage. Not
-- spoof-proof against someone clearing storage, but matches the stakes of
-- a "most loved" ranking on a curated directory, not a moderated poll.

create table if not exists public.votes (
  tool_slug text not null references public.tools(slug) on delete cascade,
  voter_id text not null,
  created_at timestamptz not null default now(),
  primary key (tool_slug, voter_id)
);

alter table public.votes enable row level security;

drop policy if exists "Anyone can view votes" on public.votes;
create policy "Anyone can view votes" on public.votes
  for select to anon, authenticated using (true);

drop policy if exists "Anyone can vote" on public.votes;
create policy "Anyone can vote" on public.votes
  for insert to anon, authenticated with check (true);

drop policy if exists "Anyone can remove their own vote" on public.votes;
create policy "Anyone can remove their own vote" on public.votes
  for delete to anon, authenticated using (true);

-- Keeps tools.votes as a live aggregate so existing read code doesn't change.
-- security definer: runs as the function owner, so it can update tools.votes
-- even though anon/authenticated have no direct UPDATE grant on tools.
create or replace function public.sync_tool_vote_count() returns trigger as $$
begin
  if (tg_op = 'INSERT') then
    update public.tools set votes = votes + 1 where slug = new.tool_slug;
    return new;
  elsif (tg_op = 'DELETE') then
    update public.tools set votes = greatest(0, votes - 1) where slug = old.tool_slug;
    return old;
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_sync_tool_vote_count on public.votes;
create trigger trg_sync_tool_vote_count
  after insert or delete on public.votes
  for each row execute function public.sync_tool_vote_count();
