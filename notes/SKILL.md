---
name: notes
description: >
  Use this skill when the user types "/notes" or "@notes" with phrases like
  "save this", "document this", "file this under <project/client>", "extract
  decisions", "extract action items", or "update notes from this discussion".
  The skill spawns the notes-librarian subagent to extract durable knowledge
  and file it into the right Docmost page using the existing workspace
  structure. Falls back to a configured inbox page when confidence is low.
argument-hint: "[save|file under <name>|extract decisions|update]"
---

# /notes — Internal Notes Librarian

Agentic note-filing skill for a Docmost wiki. Tag `/notes` (or `@notes`) during a chat. A subagent extracts durable knowledge by category, picks the best existing destination from your workspace structure, and falls back to an inbox when confidence is low.

This skill does not restructure your workspace. It learns from what's already there and files into existing pages.

## First-time setup

Run the setup script once after install:

```bash
./scripts/setup.sh
```

It will:

1. Ask for your Docmost base URL (e.g. `http://localhost:3000` or `https://docs.example.com`).
2. Ask for the agent account email + password.
3. Authenticate, store the JWT at `~/.docmost/token`.
4. Save the base URL and email at `~/.docmost/config`.
5. Discover your spaces and prompt you to choose which one is the **inbox parent** for low-confidence notes. Optionally have the script create an `AI Notes Agent` parent page with `Operating Rules`, `Filing Rules Learned`, `Inbox / Needs Review`, `Proposed Improvements` children.
6. Write `references/config.local.md` with the resolved space + page IDs.

`config.local.md` is gitignored. Keep it on the host, never commit it.

If you already have a working Docmost token at `~/.docmost/token`, setup will reuse it.

## Trigger phrases

- `/notes save this`
- `/notes file this under <project|client>`
- `/notes extract decisions` / `/notes extract action items`
- `/notes update notes from this discussion`
- `@notes ...` (same thing)
- "document this", "save this discussion", "log this conversation"

## What the skill does

1. Capture the conversation slice the user is referring to.
2. Spawn the `notes-librarian` subagent (`agents/notes-librarian.md`) with a self-contained prompt.
3. Return the subagent's report.

The subagent reads `references/config.local.md` for IDs, `references/filing-rules.md` for the destination decision tree, and `references/extraction.md` for bucket rules.

## Hard rules (enforced inside the subagent)

- Append-preferred. No deletes, no moves, no renames.
- Never auto-create a client/project parent page. Unknown entities go to the Inbox as candidates.
- Every saved page leads with the metadata header (Type/Date/Source/Tags/Summary/Canonical/Topic/Project/Updated).
- Internal-documentation writing style: bullets, short sentences, commands and names as first-class content, no filler.
- Secrets never saved verbatim. Credentials trigger a rotation warning.

## Output

The subagent returns a fixed report:

```
Saved:
- Location:
- Note type:
- Confidence:
- Review status:

Captured:
- ...

Action items:
- ...

Open questions:
- ...

Updated:
- <page links>

Warnings:
- ...
```

## Files

```
notes/
├── SKILL.md                              # this file
├── agents/
│   └── notes-librarian.md                # subagent definition (symlinked by setup.sh)
├── references/
│   ├── config.md                         # public defaults + how to override
│   ├── config.local.example.md           # template; copy to config.local.md
│   ├── extraction.md                     # bucket definitions
│   └── filing-rules.md                   # destination decision tree
└── scripts/
    ├── setup.sh                          # interactive first-time setup
    └── notes.sh                          # Docmost API wrapper
```

## Updating workspace cache

When new clients/projects are added to Docmost, re-run `./scripts/setup.sh --refresh` to update the cached lists in `config.local.md`.
