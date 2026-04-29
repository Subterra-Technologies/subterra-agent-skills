# Filing Rules

Decision tree for picking a destination. Apply top-down; first match wins.

These rules describe the *pattern*. The actual space and parent IDs come from `config.local.md`.

## 1. Explicit user destination

If the user said "file under X", use X — unless it conflicts with rule 2 (`routing_exceptions` in config). Note any override in Warnings.

## 2. Routing exceptions

Some clients / projects may live in a dedicated space outside the main `Projects` space. These are listed under `routing_exceptions` in `config.local.md`. Always honor those before rule 3.

Example shape:

```yaml
routing_exceptions:
  "BigClient":
    space: "BigClient"
    reason: "Promoted to standalone space"
```

When the conversation mentions a name in this map, route to the listed space, never the generic Projects parent.

## 3. Known client / project mentioned

Match the conversation against the cached lists in `config.local.md`:

- `known_clients_active` → child page under the Active parent.
- `known_clients_discussion` → child page under the Discussion parent.
- `known_internal_tools` → child page under the Internal parent.

If no match, do a Docmost `POST /api/search` with the candidate name as the query. A strong title hit in the right space counts as a match.

If multiple clients are mentioned, pick the dominant subject. If two are roughly equal, mark Medium confidence and use the most-recently-mentioned as primary; mirror in Inbox.

## 4. Decision record

Conversation contains "we chose / decided / going with X because Y" and the trade-off is the dominant content → `Decisions` space, flat. Title format: `YYYY-MM-DD: Short summary`.

## 5. Canonical reference

Durable how-to / setup / config / troubleshooting with no specific project → `Reference` space. Look for a matching category parent (search by topic keywords); only create new top-level reference pages if the user explicitly requests.

## 6. Worklog with no subject

If extraction yields mostly journal-style activity with no clear project/client → `Journal`. Append to today's daily page; create the daily page if missing under the current month's parent.

Default journal hierarchy: `YYYY-MM Month` → `YYYY-MM-DD Weekday`. Skip these conventions only if the workspace clearly uses a different one.

## 7. New / unknown entity

Conversation references a project, client, or system not in `config.local.md` and search returns no strong hit → **Inbox** as a candidate. Do not create a new client/project parent page. The Inbox entry's Suggested destination should say `new candidate: <name>` so a human can promote it.

## 8. Truly ambiguous

Nothing scores well, or several rules tie → Inbox only.

## Confidence scoring

- **High**: exactly one strong title hit in the right space + at least one supporting tag/keyword match. No conflicting hits.
- **Medium**: multiple plausible hits, or rule 3 with ambiguous primary, or routing exception triggered.
- **Low**: no strong hit, or rule 7 (new entity), or extraction yields almost nothing durable.

## Write modes

| Destination | Mode |
|---|---|
| Journal daily page | append |
| Project/client topic child (existing) | append |
| Project/client topic child (new dated) | create |
| Decisions | create |
| Reference (existing canonical) | append by default; replace only when user says "rewrite" |
| Inbox | append |
| Skill-owned pages (Operating Rules, Filing Rules Learned) | replace allowed |

## What this skill must never do

- Delete a page.
- Move a page.
- Rename a page.
- Auto-create a new client/project parent.
- Replace content on a page it does not own.
- Save secret values verbatim.
