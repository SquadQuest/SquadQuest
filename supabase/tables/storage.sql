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