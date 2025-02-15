CREATE EXTENSION pg_cron;

CREATE EXTENSION postgis;

CREATE FUNCTION set_updated_timestamp () RETURNS TRIGGER AS $$
BEGIN
  IF NEW IS DISTINCT FROM OLD THEN
    NEW.updated_at = now();
  END IF;
  RETURN NEW;
END;
$$ language 'plpgsql';

create view
  public.auth_users as
select
  id,
  created_at AS joined_at,
  phone,
  raw_app_meta_data -> 'invite_friends' AS invite_friends,
  raw_app_meta_data -> 'invite_events' AS invite_events
from
  auth.users;

revoke all on public.auth_users
from
  anon,
  authenticated;