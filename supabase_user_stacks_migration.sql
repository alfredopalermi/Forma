-- Run this once in the Supabase SQL editor (Database > SQL Editor > New query).
-- user_stacks currently has no way to tell "my stack" (actively using) apart
-- from "saved" (bookmarked for later) - both read/wrote the exact same rows.
-- This adds that distinction and the write permissions the app was missing
-- (it could only ever read this table, never insert/delete into it).
-- Table is currently empty, so this is safe to run as-is.

alter table public.user_stacks
  add column if not exists kind text not null default 'stack'
  check (kind in ('stack', 'saved'));

-- One row per (user, tool, kind) - a tool can be both stacked and saved independently.
alter table public.user_stacks
  drop constraint if exists user_stacks_user_id_tool_slug_key;
alter table public.user_stacks
  add constraint user_stacks_user_tool_kind_key unique (user_id, tool_slug, kind);

alter table public.user_stacks enable row level security;

drop policy if exists "Users can view their own stack" on public.user_stacks;
create policy "Users can view their own stack" on public.user_stacks
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "Users can add to their own stack" on public.user_stacks;
create policy "Users can add to their own stack" on public.user_stacks
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "Users can remove from their own stack" on public.user_stacks;
create policy "Users can remove from their own stack" on public.user_stacks
  for delete to authenticated using (auth.uid() = user_id);
