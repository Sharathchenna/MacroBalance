-- Adaptive goals ticket 04: the date `age` was recorded, so the age used in
-- the maths goes up on its own (spec §4, §6.5). Safe to run more than once.
alter table public.user_macros
  add column if not exists age_recorded_on date;

-- Existing ages were recorded when the row was last written; their real
-- date is unknown, so start the clock from the last update.
update public.user_macros
   set age_recorded_on = coalesce(updated_at::date, current_date)
 where age is not null and age_recorded_on is null;
