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
        constraint app_versions_pkey primary key (build),
        constraint app_versions_version_key unique (version)
    );

alter table public.app_versions enable row level security;