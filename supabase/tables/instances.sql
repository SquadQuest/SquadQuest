create type public.instance_visibility as enum (
    'private',
    'friends',
    'public'
);

create table
  public.instances (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    created_by uuid null default uid (),
    start_time_min timestamp with time zone null,
    start_time_max timestamp with time zone null,
    topic uuid null,
    title character varying null,
    visibility public.instance_visibility null default 'private'::instance_visibility,
    constraint instances_pkey primary key (id),
    constraint instances_topic_fkey foreign key (topic) references topics (id),
    constraint instances_created_by_fkey foreign key (created_by) references profiles (id)
  );
