-- Finish-day reminder (spec 8, decision 6): off by default. The flag lets the
-- server add the "Finish day" prompt to a user's meal reminder instead of a
-- second push. The reminder's time stays on the device.
alter table public.user_notification_preferences
  add column if not exists finish_day_reminder boolean not null default false;
