# Plans

Specs describe **state** (what should be true). Plans describe **motion** (how we're getting
there next). Every chunk of feature work starts with a plan file here declaring its scope,
the specs it implements, its dependencies, and concrete validation criteria. Together the
plan files form a micro-DAG that is the project's working plan.

Plans are temporal: once merged, a plan freezes as historical record (its merged-PR link +
completed validation criteria are the memory of what got built and what was deferred).

## Authoring & lifecycle

A plan's frontmatter:

```yaml
---
status: planned          # planned | in-progress | done | blocked | cancelled
depends: [other-plan-slug]
specs: [specs/architecture.md, ...]   # spec files THIS plan implements
issues: []
pr:                      # set at closeout
---
```

Body sections: **Scope**, **Implements**, **Approach**, **Validation** (checkbox list —
flips in-progress → done), **Risks / unknowns**, **Notes** (closeout), **Follow-ups**
(closeout). The full protocol (status lifecycle, the closeout-commit ritual, the Follow-ups
taxonomy) lives in the SpecOps skill's `references/plans-protocol.md`.

## Querying the DAG

Don't hand-maintain a DAG drawing or status table here — they rot. The SpecOps CLI computes
readiness/ordering/graph on demand from plan frontmatter:

```
<specops-skill>/scripts/specops            # dashboard: ready / blocked
<specops-skill>/scripts/specops next        # what to work on next
<specops-skill>/scripts/specops dag         # mermaid graph
```

(The `<specops-skill>` path resolves automatically when SpecOps is active; the project hook
loads the dashboard at session start.)
