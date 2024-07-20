create table
    public.topic_members (
        topic uuid not null,
        member uuid not null,
        created_at timestamp with time zone null default now(),
        constraint topic_members_pkey primary key (topic, member),
        constraint public_topic_members_topic_fkey foreign key (topic) references topics (id) on delete cascade,
        constraint public_topic_members_member_fkey foreign key (member) references profiles (id) on delete cascade
    );

alter table public.topic_members enable row level security;

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