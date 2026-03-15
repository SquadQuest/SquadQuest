-- Enable required extensions
create extension if not exists vector;
create extension if not exists pg_trgm;

create table
  public.topics (
    id uuid not null default gen_random_uuid (),
    created_at timestamp with time zone not null default now(),
    created_by uuid null default auth.uid (),
    name character varying null,
    display_name character varying null,
    embedding vector(384) null,
    constraint topics_pkey primary key (id),
    constraint topics_name_key unique (name),
    constraint topics_created_by_fkey foreign key (created_by) references profiles (id)
  );

alter table public.topics enable row level security;

-- Trigram indexes for fast typeahead
create index topics_name_trgm_idx on public.topics using gin (name gin_trgm_ops);
create index topics_display_name_trgm_idx on public.topics using gin (display_name gin_trgm_ops);

-- Vector index for semantic search
create index topics_embedding_idx on public.topics
  using ivfflat (embedding vector_cosine_ops) with (lists = 10);

-- Trigram search function for fast typeahead
create or replace function search_topics_trigram(query text, max_results int default 10)
returns table (id uuid, name varchar, display_name varchar, similarity real)
language sql stable
as $$
  select
    t.id,
    t.name,
    t.display_name,
    greatest(
      similarity(t.name, query),
      similarity(coalesce(t.display_name, ''), query)
    ) as similarity
  from public.topics t
  where
    t.name % query
    or t.display_name % query
  order by similarity desc
  limit max_results;
$$;

-- Semantic search function using pgvector
create or replace function search_similar_topics(
  query_embedding vector(384),
  similarity_threshold float default 0.5,
  max_results int default 5
)
returns table (id uuid, name varchar, display_name varchar, similarity float)
language sql stable
as $$
  select
    t.id,
    t.name,
    t.display_name,
    1 - (t.embedding <=> query_embedding) as similarity
  from public.topics t
  where
    t.embedding is not null
    and 1 - (t.embedding <=> query_embedding) > similarity_threshold
  order by t.embedding <=> query_embedding
  limit max_results;
$$;

-- Topic neighborhoods: find related topics for a given topic
create or replace function get_related_topics(topic_id uuid, max_results int default 5)
returns table (id uuid, name varchar, display_name varchar, similarity float)
language sql stable
as $$
  select
    t.id,
    t.name,
    t.display_name,
    1 - (t.embedding <=> ref.embedding) as similarity
  from public.topics t
  cross join public.topics ref
  where
    ref.id = topic_id
    and t.id != topic_id
    and t.embedding is not null
    and ref.embedding is not null
  order by t.embedding <=> ref.embedding
  limit max_results;
$$;

-- Merge topics: move all references from one topic to another, then delete the duplicate
create or replace function merge_topics(keep_id uuid, remove_id uuid)
returns void
language plpgsql
as $$
begin
  -- Move topic_members
  update public.topic_members
  set topic = keep_id
  where topic = remove_id
  and not exists (
    select 1 from public.topic_members
    where topic = keep_id and member = topic_members.member
  );

  -- Delete remaining duplicate topic_members
  delete from public.topic_members where topic = remove_id;

  -- Move instances (events)
  update public.instances
  set topic = keep_id
  where topic = remove_id;

  -- Delete the duplicate topic
  delete from public.topics where id = remove_id;
end;
$$;