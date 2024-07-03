insert into
    storage.buckets (id, name, public, allowed_mime_types)
values
    (
        'avatars',
        'avatars',
        true,
        ARRAY['image/jpeg', 'image/png']
    );

create policy "Authenticated users can select profile photos" ON storage.objects as PERMISSIVE for
SELECT
    to authenticated using (bucket_id = 'avatars');

create policy "Authenticated users can insert profile photos" ON storage.objects as PERMISSIVE for INSERT to authenticated
with
    check (bucket_id = 'avatars');

create policy "Authenticated users can update profile photos" ON storage.objects as PERMISSIVE for
UPDATE to authenticated using (true)
with
    check (bucket_id = 'avatars');