# subterra-agent-skills

Public agent skills for Claude Code, Codex, and 50+ other coding agents. Compatible with Vercel's [`npx skills`](https://github.com/vercel-labs/skills) installer and the Anthropic [`SKILL.md`](https://skills.sh) standard.

## Skills

### notes

Agentic note-filing skill for a Docmost wiki. Tag `/notes` (or `@notes`) during a chat — a subagent extracts durable knowledge by category, picks the best existing destination from your workspace structure, and falls back to an inbox when confidence is low.

See [`skills/notes/SKILL.md`](skills/notes/SKILL.md).

## Install

Requires Node.js (for `npx`).

```bash
# Pick from a menu (recommended)
npx skills add Subterra-Technologies/subterra-agent-skills

# Or install everything to all detected agents
npx skills add Subterra-Technologies/subterra-agent-skills --all

# Or pin a release
npx skills add Subterra-Technologies/subterra-agent-skills@v0.2.0

# Or install just one skill to specific agents
npx skills add Subterra-Technologies/subterra-agent-skills \
  --skill notes --agent claude-code --agent codex
```

The installer symlinks each skill into the right place for every detected coding agent. See [`vercel-labs/skills`](https://github.com/vercel-labs/skills) for all flags.

## Per-skill setup

The `notes` skill needs a one-time Docmost configuration. Easiest way: just invoke `/notes` in your agent — it detects missing config and offers to run setup for you.

To run it manually (after `npx skills add`):

```bash
~/.agents/skills/notes/scripts/setup.sh
```

If your `npx skills` install put the skills somewhere else, find with:

```bash
find ~ -maxdepth 5 -type f -path '*notes/scripts/setup.sh' 2>/dev/null
```

**Auth uses a Docmost API key (Bearer token), not a user account.** Generate one in Docmost → Settings → Account → API keys before running setup.

The script will:

1. Prompt for Docmost base URL and the API key
2. Verify the key works, store at `~/.docmost/api-key` (chmod 600)
3. Save non-secret config to `~/.docmost/config`
4. Discover spaces and prompt for the inbox parent
5. Optionally create the `AI Notes Agent` parent + 4 subpages
6. Write `references/config.local.md` (gitignored)
7. Symlink `agents/notes-librarian.md` into `~/.claude/agents/` and `~/.codex/agents/` so the orchestrator can spawn the librarian as a subagent

Rotate by revoking the key in Docmost and re-running setup.

Re-run with `--refresh` to update cached entity lists (e.g. after adding new clients in Docmost).

## Adding skills to this repo

Each skill lives at `skills/<name>/` with a `SKILL.md` at its root. Frontmatter:

```yaml
---
name: <skill-name>
description: <when to invoke this skill>
---
```

If the skill needs a subagent, add `agents/<agent-name>.md`. Per-skill setup scripts live at `scripts/setup.sh` and are documented in the skill's `SKILL.md`.

After committing, bump the version with a tag and GitHub release:

```bash
git tag -a v0.X.Y -m "..."
git push --tags
gh release create v0.X.Y --notes "..."
```

## License

MIT.
