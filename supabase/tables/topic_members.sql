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