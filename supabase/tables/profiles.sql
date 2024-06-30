create table
  public.profiles (
    id uuid not null,
    first_name text not null,
    last_name text not null,
    phone text not null,
    fcm_token text null,
    constraint profiles_pkey primary key (id),
    constraint profiles_id_fkey foreign key (id) references users (id)
  );

alter table public.profiles enable row level security;

create policy "Authenticated users can read all profiles" on "public"."profiles" as PERMISSIVE for
SELECT
  to authenticated using (true);

create policy "Authenticated users can insert their own profile" on "public"."profiles" as PERMISSIVE for INSERT to authenticated
with
  check (id = auth.uid ());

create policy "Authenticated users can update their own profile" on "public"."profiles" as PERMISSIVE for
UPDATE to authenticated using (id = auth.uid ())
with
  check (id = auth.uid ());