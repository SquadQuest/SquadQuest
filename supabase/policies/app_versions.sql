create policy "Anyone can read all app versions" on "public"."app_versions" as PERMISSIVE for
SELECT
    to public using (true);

create role "github_release_action";

grant github_release_action to authenticator;

grant authenticated to github_release_action;

create policy "GitHub Release Action can insert app versions" on "public"."app_versions" as PERMISSIVE for INSERT to github_release_action
with
    check (true);