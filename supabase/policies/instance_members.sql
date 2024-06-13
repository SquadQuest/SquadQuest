-- Users can read their own instances and own memberships
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


-- Authenticated users can read all xrefs
create policy "Authenticated users can read all xrefs"
on "public"."instance_members"
as PERMISSIVE
for SELECT
to authenticated
using (
    true
);

create policy "Service Role can read all RSVPs"
on "public"."instance_members"
as PERMISSIVE
for SELECT
to service_role
using (
    true
);

create policy "Service Role can insert RSVP"
on "public"."instance_members"
as PERMISSIVE
for INSERT
to service_role
with check (
    true
);


create policy "Service Role can update RSVPs"
on "public"."instance_members"
as PERMISSIVE
for UPDATE
to service_role
using (
    true
)
with check (
    true
);
