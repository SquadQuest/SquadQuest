create table
  public.profiles (
    id uuid not null,
    first_name text not null,
    last_name text not null,
    phone text not null,
    constraint profiles_pkey primary key (id),
    constraint profiles_id_fkey foreign key (id) references users (id)
  );
