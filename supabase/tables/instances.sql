create type public.instance_visibility as enum('private', 'friends', 'public');

create type public.instance_status as enum('draft', 'live', 'canceled');

create table
  public.instances (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    created_by uuid not null default auth.uid (),
    updated_at timestamp with time zone null,
    status public.instance_status not null default 'live'::instance_status,
    start_time_min timestamp with time zone null,
    start_time_max timestamp with time zone null,
    end_time timestamp with time zone null,
    topic uuid null,
    title character varying null,
    visibility public.instance_visibility null default 'private'::instance_visibility,
    location_description text not null,
    rally_point geography not null,
    rally_point_text text GENERATED ALWAYS AS (ST_AsText (rally_point)) STORED,
    link text null,
    notes text null,
    banner_photo text null,
    constraint instances_pkey primary key (id),
    constraint instances_topic_fkey foreign key (topic) references topics (id),
    constraint instances_created_by_fkey foreign key (created_by) references profiles (id)
  );

alter table public.instances enable row level security;

CREATE TRIGGER instance_rallypoint_change
AFTER
UPDATE OF rally_point ON instances FOR EACH ROW
execute function "supabase_functions"."http_request" (
  'http://functions:9000/update-event-rallypoint',
  'POST',
  '{"Content-Type":"application/json"}',
  '{}',
  '1000'
);

CREATE TRIGGER instance_status_change
AFTER
UPDATE OF status ON instances FOR EACH ROW
execute function "supabase_functions"."http_request" (
  'http://functions:9000/update-event-status',
  'POST',
  '{"Content-Type":"application/json"}',
  '{}',
  '1000'
);

CREATE TRIGGER instance_topic_set
AFTER INSERT
OR
UPDATE OF topic ON instances FOR EACH ROW
execute function "supabase_functions"."http_request" (
  'http://functions:9000/set-event-topic',
  'POST',
  '{"Content-Type":"application/json"}',
  '{}',
  '1000'
);

CREATE TRIGGER instance_end_time_set
AFTER INSERT
OR
UPDATE OF end_time ON instances FOR EACH ROW
execute function "supabase_functions"."http_request" (
  'http://functions:9000/set-event-end-time',
  'POST',
  '{"Content-Type":"application/json"}',
  '{}',
  '1000'
);

CREATE TRIGGER instance_updated_timestamp BEFORE
UPDATE ON instances FOR EACH ROW
EXECUTE PROCEDURE set_updated_timestamp ();