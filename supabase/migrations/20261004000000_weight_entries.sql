-- Weight history, one row per user per day, so it survives reinstalls and
-- shows on every device. The app writes with upsert on (user_id, recorded_on).
create table if not exists public.weight_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  recorded_on date not null,
  weight_kg numeric(5, 2) not null check (weight_kg > 0),
  source text not null default 'manual',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, recorded_on)
);

alter table public.weight_entries enable row level security;

create policy "Users read their own weight entries"
  on public.weight_entries for select
  using (auth.uid() = user_id);

create policy "Users add their own weight entries"
  on public.weight_entries for insert
  with check (auth.uid() = user_id);

create policy "Users update their own weight entries"
  on public.weight_entries for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users delete their own weight entries"
  on public.weight_entries for delete
  using (auth.uid() = user_id);
