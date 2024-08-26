create policy "Members of event can read messages" on "public"."event_messages" as PERMISSIVE for
SELECT
    to authenticated using (
        EXISTS (
            SELECT
            FROM
                instance_members
            WHERE
                instance_members.instance = event_messages.instance
                AND instance_members.member = auth.uid ()
        )
    );

create policy "Members of event can insert messages" on "public"."event_messages" as PERMISSIVE for INSERT to authenticated
with
    check (
        EXISTS (
            SELECT
            FROM
                instance_members
            WHERE
                instance_members.instance = event_messages.instance
                AND instance_members.member = auth.uid ()
        )
    );