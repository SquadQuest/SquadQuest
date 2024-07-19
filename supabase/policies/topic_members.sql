create policy "Authenticated users can select their own topic memberships" on "public"."topic_members" as PERMISSIVE for
SELECT
    to authenticated using (member = auth.uid ());

create policy "Authenticated users can insert their own topic memberships" on "public"."topic_members" as PERMISSIVE for INSERT to authenticated
with
    check (member = auth.uid ());

create policy "Authenticated users can update their own topic memberships" on "public"."topic_members" as PERMISSIVE for
UPDATE to authenticated using (member = auth.uid ())
with
    check (member = auth.uid ());

create policy "Authenticated users can delete their own topic memberships" on "public"."topic_members" as PERMISSIVE for DELETE to authenticated using (member = auth.uid ());

CREATE VIEW
    my_topic_memberships
WITH
    (security_invoker = true) AS
SELECT
    topics.id as topic,
    case
        when topic_members.topic is null then false
        else true
    end as subscribed,
    COUNT(instances) as events
FROM
    topics
    LEFT JOIN topic_members ON (topic = topics.id)
    LEFT JOIN instances ON (instances.topic = topics.id)
GROUP BY
    topics.id,
    topic_members.topic;