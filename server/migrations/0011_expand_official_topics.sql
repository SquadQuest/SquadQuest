-- Expand + categorize the official activity types, informed by the v1 topics dump
-- (99 real topics; messy but rich). This migration: (1) backfills `category` on the
-- 23 already-seeded official topics; (2) inserts curated additions drawn from the v1
-- corpus — the clearly-legit ones, deduped against the existing set, genre/variant
-- spam collapsed (e.g. 8 music.* genres → one "Watch Live Music"), junk dropped
-- (test/whoops/gsghsh/cat.worship/…). Categories extend the ctufts six with Music +
-- Civic, which the v1 dot-prefixes (music.*, politics.*, protest, volunteer) surfaced.
--
-- Idempotent: backfill is keyed on label; inserts use WHERE NOT EXISTS on label.
-- Hand-written data migration (see plans/v2-activity-types-seed.md + -taxonomy).

-- (1) Backfill category on the original 23 official topics.
UPDATE "topic" SET "category" = c.category
FROM (VALUES
  ('Play Basketball','Sports'), ('Play Soccer','Sports'), ('Play Tennis','Sports'),
  ('Go Trail Running','Sports'), ('Go Road Running','Sports'), ('Go Swimming','Sports'),
  ('Go Hiking','Outdoors'), ('Go Rock Climbing','Outdoors'), ('Go Camping','Outdoors'),
  ('Go Kayaking','Outdoors'),
  ('Play Board Games','Games'), ('Play Video Games','Games'),
  ('Go to Trivia Night','Games'), ('Play Card Games','Games'),
  ('Learn Cooking','Food & Drink'), ('Go Wine Tasting','Food & Drink'),
  ('Grab Coffee','Food & Drink'),
  ('Do Photography','Arts'), ('Make Painting','Arts'),
  ('Watch Live Music','Music'),
  ('Watch a Movie','Social'), ('Join Book Club','Social'), ('Sing Karaoke','Social')
) AS c(label, category)
WHERE "topic"."label" = c.label AND "topic"."category" IS NULL;

-- (2) Curated additions from the v1 corpus.
INSERT INTO "topic" ("noun", "verb", "label", "kind", "category")
SELECT v.noun, v.verb, v.label, 'official'::topic_kind, v.category
FROM (VALUES
  -- Sports / movement
  ('Yoga',            'Do',    'Do Yoga',            'Sports'),
  ('Group Bike Ride', 'Go on', 'Go on a Group Bike Ride', 'Sports'),
  ('Bike Race',       'Race',  'Race Bikes',         'Sports'),
  ('Dancing',         'Go',    'Go Dancing',         'Sports'),
  ('Sauna',           'Hit',   'Hit the Sauna',      'Sports'),
  -- Outdoors
  ('Park Picnic',     'Have',  'Have a Park Picnic', 'Outdoors'),
  ('Park Hang',       'Hang',  'Hang in the Park',   'Outdoors'),
  -- Games
  ('Bingo',           'Play',  'Play Bingo',         'Games'),
  -- Food & Drink
  ('Brunch',          'Get',   'Get Brunch',         'Food & Drink'),
  ('Dinner',          'Get',   'Get Dinner',         'Food & Drink'),
  ('Cocktails',       'Grab',  'Grab Cocktails',     'Food & Drink'),
  ('Dive Bar',        'Hit',   'Hit a Dive Bar',     'Food & Drink'),
  ('Ice Cream',       'Get',   'Get Ice Cream',      'Food & Drink'),
  ('Potluck',         'Host',  'Host a Potluck',     'Food & Drink'),
  -- Arts / culture
  ('Art Show',        'See',   'See an Art Show',    'Arts'),
  ('Art Walk',        'Go on', 'Go on an Art Walk',  'Arts'),
  ('Theater',         'See',   'See Theater',        'Arts'),
  ('Museum',          'Visit', 'Visit a Museum',     'Arts'),
  ('Comedy Show',     'See',   'See a Comedy Show',  'Arts'),
  ('Reading',         'Do',    'Do Some Reading',    'Arts'),
  -- Music
  ('Concert',         'Go to', 'Go to a Concert',    'Music'),
  ('Live Band',       'See',   'See a Live Band',    'Music'),
  -- Social / parties
  ('House Party',     'Go to', 'Go to a House Party', 'Social'),
  ('Birthday Party',  'Throw', 'Throw a Birthday Party', 'Social'),
  ('Block Party',     'Throw', 'Throw a Block Party', 'Social'),
  ('Coworking',       'Go',    'Go Coworking',       'Social'),
  ('Festival',        'Go to', 'Go to a Festival',   'Social'),
  -- Civic / community
  ('Volunteering',    'Go',    'Go Volunteering',    'Civic'),
  ('Rally',           'Go to', 'Go to a Rally',      'Civic'),
  ('Protest',         'Join',  'Join a Protest',     'Civic')
) AS v(noun, verb, label, category)
WHERE NOT EXISTS (SELECT 1 FROM "topic" t WHERE t.label = v.label);
