-- Run this once in the Supabase SQL editor (Database > SQL Editor > New query).
-- The "Submit a tool" form validated input, showed "Thank you, received!",
-- then discarded the data entirely - nothing was ever saved, emailed, or
-- logged anywhere. This gives it somewhere real to land: a moderation
-- queue, matching the form's own copy ("We review every tool manually").
--
-- Anyone can insert (that's the point of a public submission form) but
-- nobody but you can read the queue - view/manage submissions from the
-- Supabase dashboard's Table Editor (your dashboard session bypasses RLS).

create table if not exists public.tool_submissions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  url text not null,
  category text,
  pricing text,
  description text,
  submitter_email text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

alter table public.tool_submissions enable row level security;

drop policy if exists "Anyone can submit a tool" on public.tool_submissions;
create policy "Anyone can submit a tool" on public.tool_submissions
  for insert to anon, authenticated with check (true);
