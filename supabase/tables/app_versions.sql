create type public.app_version_availability as enum(
    'web',
    'android',
    'ios',
    'githubAPK',
    'testflight'
);

create table
    public.app_versions (
        build integer not null,
        version text not null,
        released timestamp with time zone not null default now(),
        supported boolean not null default true,
        notices text null,
        news text null,
        availability app_version_availability[] null,
        constraint app_versions_pkey primary key (build)
    );

-- revert to fully public after no clients < 78 are active
create policy "Anyone can read all app versions their client supports" on "public"."app_versions" as PERMISSIVE for
SELECT
    to public using (
        (
            SELECT
                fcm_token_app_build
            FROM
                profiles
            WHERE
                id = auth.uid ()
        ) >= 78
        OR 'ios' = ANY (availability)
    );