create table
  public.topics (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    created_by uuid null default uid (),
    name character varying null,
    constraint topics_pkey primary key (id),
    constraint topics_created_by_fkey foreign key (created_by) references profiles (id)
  );
