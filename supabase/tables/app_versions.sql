create table
    public.app_versions (
        build integer not null,
        version text not null,
        released timestamp with time zone not null default now(),
        supported boolean not null default true,
        notices text null,
        news text null,
        constraint app_versions_pkey primary key (build)
    );

create policy "Anyone can read all app versions" on "public"."app_versions" as PERMISSIVE for
SELECT
    to public using (true);