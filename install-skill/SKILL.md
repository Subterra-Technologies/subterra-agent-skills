---
name: install-skill
description: >
  Use this skill when the user says "/install-skill", "install a skill from
  git", "pull skill from <repo>", "add this skill to claude/codex", or wants
  to install or update a shared agent skill from a git repository. Installs
  to ~/.agent-skills/<name>/ and symlinks into both ~/.claude/skills/ and
  ~/.codex/skills/ so the same skill works for both agents. Prompts for
  credentials when the repo is private.
argument-hint: "<git-url> [name] [--branch <ref>] [--update] [--only <skill>]"
---

# /install-skill — Universal Skill Installer

Installs a skill from a git repo into the shared layout used by Claude Code and Codex.

## Layout convention

```
~/.agent-skills/<repo>/         # canonical clone (single source of truth)
~/.claude/skills/<skill>        # symlink → repo or repo/<subdir>
~/.codex/skills/<skill>         # symlink → same target
~/.claude/agents/<agent>.md     # symlink → repo/<skill>/agents/<agent>.md (if any)
~/.codex/agents/<agent>.md      # symlink → same target
```

Both agents read the same files. Update once, both pick it up.

## Repo layouts supported

- **Single skill** — `SKILL.md` at repo root. The skill installs as `<repo-name>`.
- **Monorepo** — multiple subdirs, each with its own `SKILL.md`. All are installed by default; restrict with `--only <name>`.

For each detected skill, any `agents/*.md` files are also symlinked into both agent dirs so the orchestrator can spawn them as subagents.

## Usage

```
/install-skill <git-url> [name] [--branch <ref>] [--update] [--only <skill>]
```

- `git-url` — HTTPS or SSH. Examples:
  - `https://github.com/acme/my-skill.git`
  - `git@github.com:acme/my-skill.git`
  - `https://gitlab.internal.example.com/team/skill-foo.git`
- `name` — optional override; default is the repo basename.
- `--branch <ref>` — branch or tag (default `main`).
- `--update` — pull latest into an existing install.
- `--only <skill>` — for monorepos, install just the named subdir.

## Behavior

1. Resolve target name from URL or arg.
2. If `~/.agent-skills/<name>/` exists and `--update` was passed, `git -C` pull. Otherwise refuse and tell the user to pass `--update`.
3. If the URL is HTTPS and the host needs auth, prompt the user for credentials:
   - **Username + token** (recommended for GitHub/GitLab — token can be a PAT).
   - Use `git -c credential.helper='!f(){ echo "username=$GIT_USER"; echo "password=$GIT_TOKEN"; };f'` for one-shot auth.
   - Never write the token to disk. Pass via env vars, unset after.
4. If SSH, the user's existing key is used. If it fails, fall back to HTTPS prompt.
5. Clone to `~/.agent-skills/<name>/`.
6. Validate that the clone contains a `SKILL.md` at the root. Refuse install if missing (skill is malformed).
7. Symlink into both agent locations:
   - `ln -sfn ~/.agent-skills/<name> ~/.claude/skills/<name>`
   - `ln -sfn ~/.agent-skills/<name> ~/.codex/skills/<name>`
   Create parent dirs if missing.
8. Print:
   - skill name and version (if a `VERSION` file exists or via `git describe`)
   - SKILL.md description first line
   - both symlink paths

## How to invoke

Run `~/.claude/skills/install-skill/scripts/install.sh` with the parsed args. The script does the work and prints a status report. The skill does not need a subagent.

If the user has not provided a URL, prompt for it (use AskUserQuestion). Do not assume.

## Credentials prompting

If git asks for a password and the user is in an interactive session, ask them with AskUserQuestion-style flow before invoking the script:

- "Is this repo public or private?"
- If private + HTTPS: ask for username and token. Pass to the script as `GIT_USER` and `GIT_TOKEN` env vars only. Do not log them.
- If private + SSH: confirm the key path (`~/.ssh/id_*`) and proceed.

After the install, confirm credentials are not saved anywhere except git's own credential store if the user explicitly opts in via `--save-creds` (Phase 2; not implemented in Phase 1).

## Update

`/install-skill <name> --update` runs `git pull --ff-only` inside the existing clone. Reports the new HEAD short SHA. If the working tree is dirty (someone edited the symlinked skill in place), refuse and tell the user.

## Uninstall

Out of scope here. Use `rm -rf ~/.agent-skills/<name> && rm -f ~/.claude/skills/<name> ~/.codex/skills/<name>` manually.

## Hard rules

- Never write a token to a file.
- Never run `git pull` over a dirty tree without telling the user.
- Refuse to install a clone that has no `SKILL.md` — that's not a skill.
- Do not install to anywhere outside `~/.agent-skills/<name>/`.
