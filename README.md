# subterra-agent-skills

Public agent skills for Claude Code and Codex.

Skills install to `~/.agent-skills/<name>/` and are symlinked into both `~/.claude/skills/<name>` and `~/.codex/skills/<name>` so the same source works for both agents.

## Skills

### install-skill

Universal skill installer. Clones any skill repo into the shared layout and symlinks it for both Claude Code and Codex. Prompts for credentials when the repo is private.

```
/install-skill <git-url> [name] [--branch <ref>] [--update]
```

See [`install-skill/SKILL.md`](install-skill/SKILL.md).

### notes

Agentic note-filing skill for a Docmost wiki. Tag `/notes` (or `@notes`) during a chat — a subagent extracts durable knowledge by category, picks the best existing destination, and falls back to an inbox when confidence is low.

First run requires `notes/scripts/setup.sh` to configure your Docmost URL, agent account, and workspace IDs. All instance-specific values live in `notes/references/config.local.md` (gitignored).

See [`notes/SKILL.md`](notes/SKILL.md).

## Bootstrap

One-shot bootstrap for a fresh machine — clone the repo, then `--link-only` symlinks every skill (and any subagents) into both Claude Code and Codex:

```bash
mkdir -p ~/.agent-skills
git clone https://github.com/Subterra-Technologies/subterra-agent-skills.git \
  ~/.agent-skills/subterra-agent-skills
~/.agent-skills/subterra-agent-skills/install-skill/scripts/install.sh \
  --link-only subterra-agent-skills
```

After that, use the slash command for any other skill repo:

```
/install-skill https://github.com/<org>/<repo>.git
```

### Per-skill setup

Some skills need a one-time setup script. After install, run:

```bash
~/.agent-skills/subterra-agent-skills/notes/scripts/setup.sh
```

## Skill format

Each skill is a directory with a `SKILL.md` at its root. Frontmatter:

```yaml
---
name: <skill-name>
description: <when to invoke this skill>
argument-hint: "<usage>"
---
```

## License

MIT.
