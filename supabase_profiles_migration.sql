-- Run this once in the Supabase SQL editor (Database > SQL Editor > New query).
-- Settings > Save only ever updated React state - every user's name/handle/
-- bio reset to the same hardcoded placeholders on every reload, and the
-- shown email ("alfredo@forma.app") was never the real account email.

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  name text,
  handle text,
  bio text,
  photo_url text,
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Users can view their own profile" on public.profiles;
create policy "Users can view their own profile" on public.profiles
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "Users can create their own profile" on public.profiles;
create policy "Users can create their own profile" on public.profiles
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile" on public.profiles
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
