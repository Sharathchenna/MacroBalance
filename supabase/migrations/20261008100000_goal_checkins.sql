-- Weekly check-ins (adaptive goals, spec §4 table 5, §6.8): one row per user
-- per check-in week. The row's existence is what makes a check-in run once,
-- across restarts and devices. The unique (user_id, week_start) index also
-- serves the per-user lookups.
create table if not exists public.goal_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  week_start date not null,
  variant text not null check (variant in ('changed', 'unchanged', 'insufficient', 'goal_reached', 'phase_to_maintain', 'phase_to_lose')),
  old_targets jsonb not null,         -- {cals, protein, carbs, fat}
  new_targets jsonb not null,
  reason jsonb not null,              -- {avg_intake, complete_days, weigh_ins, trend_change_kg, tdee, tdee_prev, limit_hit, ...}
  seen_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, week_start)
);

alter table public.goal_checkins enable row level security;

drop policy if exists "Users read their own check-ins" on public.goal_checkins;
create policy "Users read their own check-ins"
  on public.goal_checkins for select
  using ((select auth.uid()) = user_id);

drop policy if exists "Users add their own check-ins" on public.goal_checkins;
create policy "Users add their own check-ins"
  on public.goal_checkins for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users update their own check-ins" on public.goal_checkins;
create policy "Users update their own check-ins"
  on public.goal_checkins for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users delete their own check-ins" on public.goal_checkins;
create policy "Users delete their own check-ins"
  on public.goal_checkins for delete
  using ((select auth.uid()) = user_id);
