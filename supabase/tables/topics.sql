create table public.topics (
  id uuid not null default gen_random_uuid (),
  created_at timestamp with time zone not null default now(),
  created_by uuid null default uid (),
  name character varying null,
  constraint topics_pkey primary key (id),
  constraint topics_name_key unique (name),
  constraint topics_created_by_fkey foreign key (created_by) references profiles (id)
);

create policy "Anyone can read all topics" on "public"."topics" as PERMISSIVE for
SELECT
  to public using (true);

create policy "Authenticated users can insert topics" on "public"."topics" as PERMISSIVE for
INSERT
  to authenticated with check (true);