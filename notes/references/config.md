# Notes Skill — Config

Real values live in `config.local.md` (gitignored). This file documents the schema and shows how the skill loads configuration.

## Sources

The skill reads config in this order:

1. Environment variables (highest priority)
2. `~/.docmost/config` (set by `setup.sh`)
3. `references/config.local.md` (workspace IDs, written by `setup.sh`)
4. `references/config.md` (this file — defaults only)

## Environment variables

| Var | Purpose |
|---|---|
| `DOCMOST_URL` | Base URL of the Docmost instance (e.g. `https://docs.example.com`) |
| `DOCMOST_TOKEN_FILE` | Path to JWT token file. Default: `~/.docmost/token` |
| `DOCMOST_EMAIL` | Agent account email |

## Defaults

- API base: `http://localhost:3000`
- Token file: `~/.docmost/token`
- Public link base: same as `DOCMOST_URL`

## Schema for `config.local.md`

`setup.sh` writes this file. See `config.local.example.md` for the full schema.

Required keys:

- `api_base` — Docmost base URL
- `link_base` — public link base (often the same)
- `spaces` — table of space name → space ID
- `inbox_parent_id` — page ID where Inbox / Needs Review lives
- Optional: cached project / client lists if you want the librarian to skip a discovery call

## Auth

JWT token at `~/.docmost/token`. Refresh by re-running `setup.sh` or via the login flow:

```bash
curl -s -X POST "$DOCMOST_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$DOCMOST_EMAIL\",\"password\":\"<prompt>\"}" \
  -D - 2>&1 | grep 'set-cookie: authToken=' | sed 's/.*authToken=//;s/;.*//' > ~/.docmost/token
```

## Link format

```
${link_base}/s/<space-slug>/<page-slugId>
```
