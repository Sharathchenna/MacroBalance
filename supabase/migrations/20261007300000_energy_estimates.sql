-- Expenditure estimates (adaptive goals, spec §4 table 3): one row per user
-- per day, computed on the device by the estimator (spec 6.4) and upserted.
-- Plus the day learning started, set at onboarding and on "Reset learning".
alter table public.user_macros
  add column if not exists learning_started_on date;

create table if not exists public.energy_estimates (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  tdee numeric(6,0) not null,
  tdee_sd numeric(5,0) not null,
  state text not null check (state in ('learning', 'estimated', 'confident', 'paused')),
  trend_weight_kg numeric(5,2),
  slope_kg_per_day numeric(6,4),
  avg_intake numeric(6,0),
  complete_days smallint not null,
  weigh_ins smallint not null,
  algo_version smallint not null,
  primary key (user_id, day)
);

alter table public.energy_estimates enable row level security;

create policy "Users read their own energy estimates"
  on public.energy_estimates for select
  using ((select auth.uid()) = user_id);

create policy "Users add their own energy estimates"
  on public.energy_estimates for insert
  with check ((select auth.uid()) = user_id);

create policy "Users update their own energy estimates"
  on public.energy_estimates for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users delete their own energy estimates"
  on public.energy_estimates for delete
  using ((select auth.uid()) = user_id);
