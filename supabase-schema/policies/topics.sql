-- Anyone can read all topics
alter policy "Anyone can read all topics"
on "public"."topics"
to public
using (
    true
);


-- Authenticated users can insert topics
alter policy "Authenticated users can insert topics"
on "public"."topics"
to authenticated
with check (
    true
);
