create table
  public.location_points (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    created_by uuid null default uid (),
    timestamp timestamp with time zone not null,
    location geography(POINT) not null,
    constraint location_points_pkey primary key (id),
    constraint public_location_points_created_by_fkey foreign key (created_by) references profiles (id) on delete cascade
  );

-- delete data older than 3 days every hour
SELECT cron.schedule('55 * * * *', $$DELETE FROM location_points WHERE timestamp < now() - interval 3 day'$$);
