-- Run this once in the Supabase SQL editor (Database > SQL Editor > New query).
-- Custom collections (user-created lists) only ever lived in React state -
-- never persisted anywhere, so they vanished on refresh and never synced
-- across devices, same underlying issue as user_stacks before its migration.

create table if not exists public.user_collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  tool_slugs text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.user_collections enable row level security;

drop policy if exists "Users can view their own collections" on public.user_collections;
create policy "Users can view their own collections" on public.user_collections
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "Users can create their own collections" on public.user_collections;
create policy "Users can create their own collections" on public.user_collections
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "Users can update their own collections" on public.user_collections;
create policy "Users can update their own collections" on public.user_collections
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own collections" on public.user_collections;
create policy "Users can delete their own collections" on public.user_collections
  for delete to authenticated using (auth.uid() = user_id);
