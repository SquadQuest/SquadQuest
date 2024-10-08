create table
    public.event_messages (
        id uuid not null default gen_random_uuid (),
        created_at timestamp with time zone not null default now(),
        created_by uuid not null default auth.uid (),
        instance uuid not null,
        content text null,
        pinned boolean not null default false,
        constraint event_messages_pkey primary key (id),
        constraint event_messages_created_by_fkey foreign key (created_by) references profiles (id) on update cascade on delete cascade,
        constraint event_messages_event_id_fkey foreign key (instance) references instances (id) on update cascade on delete cascade
    );

alter table public.event_messages enable row level security;

CREATE TRIGGER event_message_create
AFTER INSERT ON event_messages FOR EACH ROW
execute function "supabase_functions"."http_request" (
  'http://functions:9000/create-event-message',
  'POST',
  '{"Content-Type":"application/json"}',
  '{}',
  '1000'
);