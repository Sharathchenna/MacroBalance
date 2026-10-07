-- Day status: the user says a day's food log is finished (complete), was a
-- fast, or wasn't fully logged. No row means "not finished". Absence of a row
-- is how "Not finished" is stored; the app deletes the row.
create table if not exists public.food_day_status (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  status text not null check (status in ('complete', 'partial', 'fasting')),
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.food_day_status enable row level security;

create policy "Users read their own day status"
  on public.food_day_status for select
  using ((select auth.uid()) = user_id);

create policy "Users add their own day status"
  on public.food_day_status for insert
  with check ((select auth.uid()) = user_id);

create policy "Users update their own day status"
  on public.food_day_status for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users delete their own day status"
  on public.food_day_status for delete
  using ((select auth.uid()) = user_id);
