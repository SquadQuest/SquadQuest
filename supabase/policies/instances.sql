-- Everyone can read public instances
create policy "Everyone can read public instances" on "public"."instances" as PERMISSIVE for
SELECT
    to authenticated using (visibility = 'public');

-- Creator & friends & members can read friends instances
create policy "Creator & friends & members can read friends instances" on "public"."instances" as PERMISSIVE for
SELECT
    to authenticated using (
        visibility = 'friends'
        AND (
            created_by = auth.uid()
            OR id IN (
                SELECT
                    instance
                FROM
                    instance_members
                WHERE
                    member = auth.uid()
            )
            OR EXISTS (
                SELECT
                FROM
                    friends
                WHERE
                    friends.status = 'accepted'
                    AND (
                        auth.uid() in (requester, requestee)
                        AND instances.created_by in (requester, requestee)
                    )
            )
        )
    );

-- Creator & members can read private instances
create policy "Creator & members can read private instances" on "public"."instances" as PERMISSIVE for
SELECT
    to authenticated using (
        visibility = 'private'
        AND (
            created_by = auth.uid()
            OR id IN (
                SELECT
                    instance
                FROM
                    instance_members
                WHERE
                    member = auth.uid()
            )
        )
    );

-- Authenticated users can insert instances
create policy "Authenticated users can insert instances" on "public"."instances" as PERMISSIVE for
INSERT
    to authenticated with check (
        auth.uid() = created_by
        OR created_by IS NULL
    );

-- Authenticated users update their own instances
create policy "Authenticated users can update their own instances" on "public"."instances" as PERMISSIVE for
UPDATE
    to authenticated using (created_by = auth.uid()) with check (created_by = auth.uid());