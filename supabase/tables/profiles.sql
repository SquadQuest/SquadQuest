create type public.notification_type as enum(
  'friendRequest',
  'eventInvitation',
  'eventChange',
  'friendsEventPosted',
  'publicEventPosted',
  'guestRsvp',
  'friendOnTheWay',
  'eventMessage'
);

create table
  public.profiles (
    id uuid not null,
    first_name text not null,
    last_name text not null,
    phone text not null,
    fcm_token text null,
    photo text null,
    fcm_token_updated_at timestamp with time zone null,
    fcm_token_app_build integer null,
    enabled_notifications notification_type[] not null default '{friendRequest,eventInvitation,eventChange,friendsEventPosted,publicEventPosted,guestRsvp,friendOnTheWay}'::notification_type[],
    enabled_notifications_v2 notification_type[] not null default '{friendRequest,eventInvitation,eventChange,friendsEventPosted,publicEventPosted,guestRsvp,friendOnTheWay,eventMessage}'::notification_type[],
    constraint profiles_pkey primary key (id),
    constraint profiles_id_fkey foreign key (id) references auth.users (id)
  );

alter table public.profiles enable row level security;

CREATE VIEW
  profiles_anonymous
WITH
  (security_invoker = false) AS
SELECT
  id,
  first_name
FROM
  profiles;

CREATE TRIGGER profile_insert
AFTER INSERT ON profiles FOR EACH ROW
execute function "supabase_functions"."http_request" (
  'http://functions:9000/on-profile-insert',
  'POST',
  '{"Content-Type":"application/json"}',
  '{}',
  '1000'
);

-- backwards compatibility for v1 and v2 enabled_notifications
CREATE FUNCTION notifications_unique (a notification_type[]) RETURNS notification_type[] AS $$
  SELECT ARRAY (
    SELECT DISTINCT v FROM unnest(a) AS b(v)
  )
$$ language sql;

CREATE FUNCTION sync_enabled_notifications () RETURNS TRIGGER AS $$
DECLARE
  v2_values notification_type[] := '{eventMessage}'::notification_type[];
  v2_value notification_type;
BEGIN
  IF NEW IS DISTINCT FROM OLD THEN
    IF NOT (NEW.enabled_notifications_v2 <@ OLD.enabled_notifications_v2 AND NEW.enabled_notifications_v2 @> OLD.enabled_notifications_v2) THEN
      NEW.enabled_notifications = NEW.enabled_notifications_v2;
      FOREACH v2_value IN ARRAY v2_values LOOP
        NEW.enabled_notifications = array_remove(NEW.enabled_notifications, v2_value);
      END LOOP;
    ELSIF NOT (NEW.enabled_notifications <@ OLD.enabled_notifications AND NEW.enabled_notifications @> OLD.enabled_notifications) THEN
      NEW.enabled_notifications_v2 = NEW.enabled_notifications;

      IF NEW.enabled_notifications_v2 && v2_values THEN
        NEW.enabled_notifications_v2 = NEW.enabled_notifications;
      END IF;

      FOREACH v2_value IN ARRAY v2_values LOOP
        NEW.enabled_notifications = array_remove(NEW.enabled_notifications, v2_value);

        IF v2_value = ANY(OLD.enabled_notifications_v2) THEN
          NEW.enabled_notifications_v2 = array_append(NEW.enabled_notifications_v2, v2_value);
        END IF;
      END LOOP;
    END IF;

    NEW.enabled_notifications = notifications_unique(NEW.enabled_notifications);
    NEW.enabled_notifications_v2 = notifications_unique(NEW.enabled_notifications_v2);
  END IF;
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER sync_enabled_notifications BEFORE
UPDATE ON profiles FOR EACH ROW
EXECUTE PROCEDURE sync_enabled_notifications ();