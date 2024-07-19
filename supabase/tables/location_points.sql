create table
  public.location_points (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    created_by uuid null default auth.uid (),
    event uuid not null,
    timestamp timestamp with time zone not null,
    location geography not null,
    location_text text GENERATED ALWAYS AS (ST_AsText (location)) STORED,
    constraint location_points_pkey primary key (id),
    constraint public_location_points_created_by_fkey foreign key (created_by) references profiles (id) on delete cascade,
    constraint public_location_points_event_fkey foreign key (event) references instances (id) on update cascade on delete cascade
  );

alter table public.location_points enable row level security;

-- delete data older than 3 days every hour
SELECT
  cron.schedule (
    'trim location_points to 1 hour',
    '55 * * * *',
    'DELETE FROM location_points WHERE timestamp < now() - interval 1 hour'
  );