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
