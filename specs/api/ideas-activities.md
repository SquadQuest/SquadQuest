# API: Ideas & Activities

The idea↔activity lifecycle: create an idea, respond, vote, the captain confirms it into an
activity, and the bring-friends bridge. Behavior/rules in
[`behaviors/ideas-activities-lifecycle.md`](../behaviors/ideas-activities-lifecycle.md),
[`response-system.md`](../behaviors/response-system.md),
[`bring-friends-bridge.md`](../behaviors/bring-friends-bridge.md). Authenticated.

## Serialized activity (wire shape)

```jsonc
{
  "id": "uuid",
  "state": "idea" | "confirmed",
  "captain": { "id", "first_name", "photo" },
  "activity_type": { "id", "label" },        // e.g. "Paddleboarding"
  "scope": "friends" | "squad",
  "squad_id": "uuid|null",
  "audience": { "kind": "all_friends" | "people", "summary": "all friends" },
  "allow_suggestions": true,
  "time_options":     [ { "id", "label", "votes": 5, "you_voted": true } ],
  "location_options": [ { "id", "label", "votes": 4, "you_voted": false } ],
  "confirmed_time": "Sun 2pm|null",          // present when state=confirmed
  "confirmed_location": "Willamette|null",
  "your_response": "in" | "interested" | "next_time" | null,
  "counts": { "in": 6, "interested": 3 },
  "thread_count": 12,
  "event_ref": { … } | null,                 // present for brought-along plans (see communities)
  "created_at": "iso8601"
}
```

## POST /v1/ideas

Create an idea (state always starts `idea`).

- **Request:**

  ```jsonc
  { "activity_type_id": "uuid",
    "scope": "friends" | "squad", "squad_id": "uuid?",
    "audience": { "kind": "all_friends" | "people", "person_ids": ["…"]? },
    "allow_suggestions": true,
    "time_options": ["Sat 7am", "Sun 8am"]?,        // optional
    "location_options": ["Willamette", "Ross Island"]?,
    "community_event_id": "uuid?"                    // set ⇒ brought-along (see below)
  }
  ```

- **Response:** `201 <activity>`.
- **Enforced:** `scope:friends` always emits a friends-scoped idea — the API rejects any
  attempt to make this public. See
  [private-first](../principles.md#private-first-public-never-touches-the-friends-surface).

## PUT /v1/ideas/:id/response

Set/replace the caller's response.

- **Request:** `{ "value": "in" | "interested" | "next_time" }`. DELETE clears it (the
  passive dismiss has no value — see [response-system](../behaviors/response-system.md)).
- **Response:** `200 <activity>` (with updated `your_response`/`counts`).

## POST /v1/ideas/:id/options

Suggest a time/location option (only if `allow_suggestions`).

- **Request:** `{ "kind": "time" | "location", "label": "Sat 10am" }` → `201 <option>`.

## PUT /v1/ideas/:id/votes

Toggle the caller's vote on an option.

- **Request:** `{ "option_id": "uuid", "voted": true }` → `200 <activity>`.

## POST /v1/ideas/:id/confirm

**Captain only.** Lock time + place → promotes the record to `state: confirmed` (same id —
two states of one record). See
[ideas-activities-lifecycle](../behaviors/ideas-activities-lifecycle.md).

- **Request:** `{ "time_option_id": "uuid?", "location_option_id": "uuid?" }` — for a
  brought-along plan, time/place come fixed from the community event; the body may be empty.
- **Response:** `200 <activity>` (now `state: confirmed`).
- **Errors:** `403 not_captain`.

## Notes

- The bring-friends flow is just `POST /v1/ideas` with `community_event_id` set; the
  resulting idea carries `event_ref` and its time/place are the event's. Detail in
  [bring-friends-bridge](../behaviors/bring-friends-bridge.md).
- Threads on an activity are `api/messages.md` with `thread_of` = this activity.

## Principles

**Inherited:**

- [Private-first](../principles.md#private-first-public-never-touches-the-friends-surface) —
  `POST /v1/ideas` can only ever produce friends/squad-scoped content.
- [Lower the stakes](../principles.md#lower-the-stakes-of-participation) — response is
  optional and clearable; no decline.
