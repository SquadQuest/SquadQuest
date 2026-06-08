# migrations/

First-class, forward-only Postgres schema migrations. The schema is free to churn
behind the versioned API (nothing outside the API binds to it). Migration tooling

+ the initial schema land in the `v2-backend-and-migration` plan. See
`specs/data-model.md`.
