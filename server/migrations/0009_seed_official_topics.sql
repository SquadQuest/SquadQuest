-- Seed the curated set of OFFICIAL activity types (v2-activity-types-seed).
-- Source: origin/ctufts/topic-exploration v7 prototype (23 topics, 6 categories).
-- Verbs absent in the prototype are given natural readings here; labels are
-- low-stakes and refined later by v2-activity-types-taxonomy + the v1 DB scan.
--
-- Idempotent: each row inserts only if no topic with that label exists yet, so
-- re-running (and running against a DB that already has some) is a no-op. Hand-
-- written (not drizzle-generated) — this is data, not schema.

INSERT INTO "topic" ("noun", "verb", "label", "kind")
SELECT v.noun, v.verb, v.label, 'official'::topic_kind
FROM (VALUES
  ('Basketball',    'Play',  'Play Basketball'),
  ('Soccer',        'Play',  'Play Soccer'),
  ('Tennis',        'Play',  'Play Tennis'),
  ('Trail Running', 'Go',    'Go Trail Running'),
  ('Road Running',  'Go',    'Go Road Running'),
  ('Swimming',      'Go',    'Go Swimming'),
  ('Hiking',        'Go',    'Go Hiking'),
  ('Rock Climbing', 'Go',    'Go Rock Climbing'),
  ('Camping',       'Go',    'Go Camping'),
  ('Kayaking',      'Go',    'Go Kayaking'),
  ('Board Games',   'Play',  'Play Board Games'),
  ('Video Games',   'Play',  'Play Video Games'),
  ('Trivia Night',  'Go to', 'Go to Trivia Night'),
  ('Card Games',    'Play',  'Play Card Games'),
  ('Cooking',       'Learn', 'Learn Cooking'),
  ('Wine Tasting',  'Go',    'Go Wine Tasting'),
  ('Coffee Meetup', 'Grab',  'Grab Coffee'),
  ('Photography',   'Do',    'Do Photography'),
  ('Painting',      'Make',  'Make Painting'),
  ('Live Music',    'Watch', 'Watch Live Music'),
  ('Movie Nights',  'Watch', 'Watch a Movie'),
  ('Book Club',     'Join',  'Join Book Club'),
  ('Karaoke',       'Sing',  'Sing Karaoke')
) AS v(noun, verb, label)
WHERE NOT EXISTS (SELECT 1 FROM "topic" t WHERE t.label = v.label);
