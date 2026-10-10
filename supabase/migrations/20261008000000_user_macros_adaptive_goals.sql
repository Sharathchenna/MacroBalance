-- AG-11: adaptive goals choice and check-in weekday (spec §4, §7.5).
-- adaptive_goals: should the targets follow the learned expenditure at weekly
-- check-ins (true) or stay fixed (false). Onboarding defaults it to true.
-- checkin_weekday: ISO weekday (1 = Monday) check-ins fall on; onboarding sets
-- it to the weekday it finished. Null for accounts from before this column.
alter table public.user_macros
  add column if not exists adaptive_goals boolean not null default true,
  add column if not exists checkin_weekday smallint
    check (checkin_weekday between 1 and 7);
