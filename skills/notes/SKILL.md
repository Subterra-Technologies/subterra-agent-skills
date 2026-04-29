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

The skill authenticates with a **Docmost API key** (Bearer token), not a user account. Generate one in Docmost:

1. Open `Settings → Account → API keys`
2. Click **Create API Key**, name it (e.g. `notes-skill`)
3. Copy the key — Docmost shows it once

Then run setup. From anywhere:

```bash
"$(dirname "$(readlink -f "$(npx --no-install skills which notes 2>/dev/null || echo ~/.agents/skills/notes/SKILL.md)")")/scripts/setup.sh"
```

Or simpler — just invoke `/notes` (or `@notes`) in your agent and it will detect the missing config and offer to run setup for you.

Direct path (after `npx skills add`):

```bash
~/.agents/skills/notes/scripts/setup.sh
```

It will:

1. Ask for your Docmost base URL (e.g. `https://docs.example.com`)
2. Ask for the API key, verify it works against `/api/spaces`, store at `~/.docmost/api-key` (chmod 600)
3. Save base URL + key path at `~/.docmost/config`
4. Discover your spaces and prompt for the **inbox parent**
5. Optionally create the `AI Notes Agent` parent + 4 subpages
6. Write `references/config.local.md` (gitignored) with the resolved IDs
7. Symlink `agents/notes-librarian.md` into `~/.claude/agents/` and `~/.codex/agents/`

`config.local.md` is gitignored. Never commit it.

Rotate by revoking the key in Docmost and re-running `./scripts/setup.sh`.

## Trigger phrases

- `/notes save this`
- `/notes file this under <project|client>`
- `/notes extract decisions` / `/notes extract action items`
- `/notes update notes from this discussion`
- `@notes ...` (same thing)
- "document this", "save this discussion", "log this conversation"

## What the skill does

1. **Preflight:** check that `<skill-dir>/references/config.local.md` exists. If not, the skill is unconfigured — tell the user "Notes skill isn't configured yet. Run setup now? (the script will prompt for your Docmost URL and API key)" and, on confirmation, execute `<skill-dir>/scripts/setup.sh` via Bash. Do not attempt to spawn the librarian without config.
2. Capture the conversation slice the user is referring to.
3. Spawn the `notes-librarian` subagent (`agents/notes-librarian.md`) with a self-contained prompt.
4. Return the subagent's report.

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
