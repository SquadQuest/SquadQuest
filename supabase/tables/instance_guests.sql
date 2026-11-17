-- A guest (see guests.sql) attached to one event, with their answer.
-- Deliberately separate from instance_members, whose `member` must be a
-- profile: v1 clients read instance_members and must never receive a row
-- shape they do not expect. See docs/guest-rsvp.md.
create table
  public.instance_guests (
    instance uuid not null,
    guest uuid not null,
    status text not null default 'invited',
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    constraint instance_guests_pkey primary key (instance, guest),
    constraint instance_guests_instance_fkey foreign key (instance) references instances (id) on delete cascade,
    constraint instance_guests_guest_fkey foreign key (guest) references guests (id) on delete cascade,
    constraint instance_guests_status_check check (status in ('invited', 'yes', 'maybe', 'no'))
  );

create index instance_guests_guest_idx on public.instance_guests (guest);

alter table public.instance_guests enable row level security;

revoke all on public.instance_guests
from
  anon,
  authenticated;

grant
select
,
  insert,
update,
delete on public.instance_guests to authenticated;

CREATE TRIGGER instance_guests_updated_timestamp BEFORE
UPDATE ON instance_guests FOR EACH ROW
EXECUTE PROCEDURE set_updated_timestamp ();
