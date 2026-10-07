-- Adaptive goals ticket 03: goal settings on user_macros (spec §4), and the
-- old fixed deficit replaced by a pace (% of body weight a week).
--
-- Older builds wrote the profile to differently named columns (gender,
-- height, body_fat_percentage, protein_ratio) and the deficit to
-- deficit_surplus. Their values are copied across where they're valid, then
-- the old columns are dropped. Safe to run more than once.

alter table public.user_macros
  add column if not exists sex text check (sex in ('male', 'female')),
  add column if not exists height_cm numeric(5,1),
  add column if not exists body_fat_pct numeric(4,1),
  add column if not exists pace_pct_per_week numeric(4,2),
  add column if not exists protein_g_per_kg numeric(3,1),
  add column if not exists formula_tdee numeric(6,0);

-- age and fat_ratio already exist.
alter table public.user_macros add column if not exists age integer;
alter table public.user_macros add column if not exists fat_ratio numeric;

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'user_macros' and column_name = 'gender') then
    update public.user_macros set sex = gender
      where sex is null and gender in ('male', 'female');
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'user_macros' and column_name = 'height') then
    update public.user_macros set height_cm = height
      where height_cm is null and height between 100 and 250;
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'user_macros' and column_name = 'body_fat_percentage') then
    update public.user_macros set body_fat_pct = body_fat_percentage
      where body_fat_pct is null and body_fat_percentage between 3 and 70;
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'user_macros' and column_name = 'protein_ratio') then
    update public.user_macros set protein_g_per_kg = protein_ratio
      where protein_g_per_kg is null and protein_ratio between 0.5 and 4;
  end if;
end $$;

-- activity_level was numeric (some rows hold multipliers like 1.55); it is a
-- 1–5 level now.
alter table public.user_macros
  alter column activity_level type smallint using (
    case when activity_level in (1, 2, 3, 4, 5) then activity_level::smallint end
  );

update public.user_macros set age = null where age not between 18 and 100;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'user_macros_activity_level_check') then
    alter table public.user_macros
      add constraint user_macros_activity_level_check check (activity_level between 1 and 5);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'user_macros_age_check') then
    alter table public.user_macros
      add constraint user_macros_age_check check (age between 18 and 100);
  end if;
end $$;

alter table public.user_macros
  drop column if exists deficit_surplus,
  drop column if exists gender,
  drop column if exists height,
  drop column if exists body_fat_percentage,
  drop column if exists protein_ratio;
