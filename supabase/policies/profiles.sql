alter table public.profiles enable row level security;

-- Authenticated users can read all profiles
create policy "Authenticated users can read all profiles"
on "public"."profiles"
as PERMISSIVE
for SELECT
to authenticated
using (
    true
);

-- Authenticated users can insert their own profile
create policy "Authenticated users can insert their own profile"
on "public"."profiles"
as PERMISSIVE
for INSERT
to authenticated
with check (
    id = auth.uid()
);


-- Authenticated users can update their own profile
create policy "Authenticated users can update their own profile"
on "public"."profiles"
as PERMISSIVE
for UPDATE
to authenticated
using (
    id = auth.uid()
)
with check (
    id = auth.uid()
);
