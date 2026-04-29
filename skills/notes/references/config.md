# Notes Skill — Config

Real values live in `config.local.md` (gitignored). This file documents the schema.

## Auth

The skill uses a **Docmost API key** with Bearer auth. No user account, no JWT login flow. Generate the key in Docmost → Settings → Account → API keys.

```
Authorization: Bearer <api-key>
```

## Sources (load order, first wins)

1. Environment variables
2. `~/.docmost/config` (set by `setup.sh`)
3. `references/config.local.md` (workspace IDs, written by `setup.sh`)
4. `references/config.md` (this file — defaults only)

## Environment variables

| Var | Purpose |
|---|---|
| `DOCMOST_URL` | Base URL of the Docmost instance |
| `DOCMOST_API_KEY_FILE` | Path to API key file. Default: `~/.docmost/api-key` |

## Schema for `config.local.md`

`setup.sh` writes this file. See `config.local.example.md` for the full schema.

Required keys:

- `api_base` — Docmost base URL
- `link_base` — public link base
- `api_key_file` — path to the API key file (chmod 600)
- `spaces` — table of space name → space ID
- `agent_area.pages.inbox` — page ID where Inbox / Needs Review lives

## Link format

```
${link_base}/s/<space-slug>/<page-slugId>
```
