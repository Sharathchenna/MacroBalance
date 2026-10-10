-- AG-17: plan styles and phases (spec §4 parts 1 and 4, §6.7).
-- plan_style: how a lose goal is arranged (steady / phased / breaks).
-- phase_loss_pct, maintenance_weeks, break_every_weeks, break_weeks: the
-- user's phase settings; null keeps the defaults (spec §5).
alter table public.user_macros
  add column if not exists plan_style text not null default 'steady'
    check (plan_style in ('steady', 'phased', 'breaks')),
  add column if not exists phase_loss_pct numeric(4,1),
  add column if not exists maintenance_weeks smallint,
  add column if not exists break_every_weeks smallint,
  add column if not exists break_weeks smallint;

-- One row per phase, numbered per user by seq; at most one is open (ended_on
-- null). end_requested_on (beyond spec §4): "End phase early" was asked that
-- day, and the next check-in ends the phase as user_ended.
create table if not exists public.goal_phases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  seq smallint not null,
  kind text not null check (kind in ('lose', 'maintain', 'gain')),
  started_on date not null,
  start_trend_kg numeric(5,2) not null,
  target_pct numeric(4,1),            -- lose phases in 'phased' style
  planned_weeks smallint,             -- maintain phases, 'breaks' lose phases
  max_weeks smallint,
  ended_on date,
  end_reason text check (end_reason in ('reached', 'max_duration', 'planned', 'skipped', 'user_ended', 'goal_reached', 'replanned')),
  end_requested_on date,
  unique (user_id, seq)
);

alter table public.goal_phases enable row level security;

drop policy if exists "Users read their own phases" on public.goal_phases;
create policy "Users read their own phases"
  on public.goal_phases for select
  using ((select auth.uid()) = user_id);

drop policy if exists "Users add their own phases" on public.goal_phases;
create policy "Users add their own phases"
  on public.goal_phases for insert
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users update their own phases" on public.goal_phases;
create policy "Users update their own phases"
  on public.goal_phases for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users delete their own phases" on public.goal_phases;
create policy "Users delete their own phases"
  on public.goal_phases for delete
  using ((select auth.uid()) = user_id);
