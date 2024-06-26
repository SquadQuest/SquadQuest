create type public.instance_member_status as enum (
  'invited',
  'no',
  'maybe',
  'yes',
  'omw'
);

create table public.instance_members (
  id uuid not null default gen_random_uuid (),
  created_at timestamp with time zone not null default now(),
  created_by uuid not null default uid (),
  instance uuid not null,
  member uuid not null,
  status public.instance_member_status not null,
  constraint instance_members_pkey primary key (id),
  constraint instance_members_created_by_fkey foreign key (created_by) references profiles (id),
  constraint public_instance_members_instance_fkey foreign key (instance) references instances (id) on delete cascade constraint instance_members_member_fkey foreign key (member) references profiles (id),
  constraint instance_member unique (instance, member)
);

-- TODO: let users see other members within instances they're a member of
-- alter policy "Users can read their own instances and own memberships"
-- on "public"."instance_members"
-- to public
-- using (
--     member = auth.uid()
--     OR instance IN (
--         SELECT id
--         FROM instances
--         WHERE instances.created_by = auth.uid()
--     )
-- );
create policy "Authenticated users can read all xrefs" on "public"."instance_members" as PERMISSIVE for
SELECT
  to authenticated using (true);