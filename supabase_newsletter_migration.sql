-- Run this once in the Supabase SQL editor (Database > SQL Editor > New query).
-- The "Subscribe" button didn't even read the email field - it just showed
-- a confirmation toast on click. Nothing was ever collected.

create table if not exists public.newsletter_subscribers (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  created_at timestamptz not null default now()
);

alter table public.newsletter_subscribers enable row level security;

drop policy if exists "Anyone can subscribe" on public.newsletter_subscribers;
create policy "Anyone can subscribe" on public.newsletter_subscribers
  for insert to anon, authenticated with check (true);
