insert into
    storage.buckets (id, name, public, allowed_mime_types)
values
    (
        'avatars',
        'avatars',
        true,
        ARRAY['image/jpeg', 'image/png', 'image/webp']
    ),
    (
        'event-banners',
        'event-banners',
        true,
        ARRAY['image/jpeg', 'image/png', 'image/webp']
    );

create policy "Authenticated users can select photos" ON storage.objects as PERMISSIVE for
SELECT
    to authenticated using (bucket_id IN ('avatars', 'event-banners'));

-- avatars
create policy "Authenticated users can insert profile photos" ON storage.objects as PERMISSIVE for INSERT to authenticated
with
    check (
        bucket_id = 'avatars'
        AND name = auth.uid ()::text
    );

create policy "Authenticated users can update profile photos" ON storage.objects as PERMISSIVE for
UPDATE to authenticated using (
    true
    AND name = auth.uid ()::text
)
with
    check (bucket_id = 'avatars');

-- event-banners
create policy "Host can insert event banner photos" ON storage.objects as PERMISSIVE for INSERT to authenticated
with
    check (
        bucket_id = 'event-banners'
        AND (
            name = CONCAT('_pending/', auth.uid ()::text)
            or EXISTS (
                SELECT
                FROM
                    instances
                WHERE
                    instances.id::text = name
                    AND instances.created_by = auth.uid ()
            )
        )
    );

create policy "Host can update event banner photos" ON storage.objects as PERMISSIVE for
UPDATE to authenticated using (true)
with
    check (
        bucket_id = 'event-banners'
        AND (
            name = CONCAT('_pending/', auth.uid ()::text)
            or EXISTS (
                SELECT
                FROM
                    instances
                WHERE
                    instances.id::text = name
                    AND instances.created_by = auth.uid ()
            )
        )
    );