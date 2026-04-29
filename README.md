# subterra-agent-skills

Public agent skills for Claude Code and Codex.

Skills install to `~/.agent-skills/<name>/` and are symlinked into both `~/.claude/skills/<name>` and `~/.codex/skills/<name>` so the same source works for both agents.

## Skills

### install-skill

Universal skill installer. Clones any skill repo into the shared layout and symlinks it for both Claude Code and Codex. Prompts for credentials when the repo is private.

```
/install-skill <git-url> [name] [--branch <ref>] [--update]
```

See [`install-skill/SKILL.md`](install-skill/SKILL.md) for full docs.

## Bootstrap

To install `install-skill` itself before you have it:

```bash
mkdir -p ~/.agent-skills ~/.claude/skills ~/.codex/skills
git clone https://github.com/<org>/subterra-agent-skills.git ~/.agent-skills/_repo
ln -sfn ~/.agent-skills/_repo/install-skill ~/.agent-skills/install-skill
ln -sfn ~/.agent-skills/install-skill ~/.claude/skills/install-skill
ln -sfn ~/.agent-skills/install-skill ~/.codex/skills/install-skill
```

After that, use `/install-skill <git-url>` for everything else.

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
