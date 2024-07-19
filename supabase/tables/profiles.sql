create table
  public.profiles (
    id uuid not null,
    first_name text not null,
    last_name text not null,
    phone text not null,
    fcm_token text null,
    photo text null,
    fcm_token_updated_at timestamp with time zone null,
    fcm_token_app_build integer null,
    constraint profiles_pkey primary key (id),
    constraint profiles_id_fkey foreign key (id) references auth.users (id)
  );

alter table public.profiles enable row level security;