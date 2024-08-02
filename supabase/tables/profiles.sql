create type public.notification_type as enum(
  'friendRequest',
  'eventInvitation',
  'eventChange',
  'friendsEventPosted',
  'publicEventPosted',
  'guestRsvp',
  'friendOnTheWay'
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