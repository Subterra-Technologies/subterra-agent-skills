#!/usr/bin/env bash
# Universal skill installer — clones a skill repo into the shared agent-skills
# layout and symlinks it into both Claude Code and Codex skill dirs.
#
# Supports both single-skill repos (SKILL.md at root) and monorepos (one or
# more subdirs each containing a SKILL.md). For each skill detected, also
# symlinks any agents/*.md files into ~/.claude/agents/ and ~/.codex/agents/.
#
# Usage:
#   install.sh <git-url> [name] [--branch <ref>] [--update] [--only <skill>]
#
# Auth (HTTPS private repos): set GIT_USER and GIT_TOKEN in env. They are used
# once via a transient credential helper and never written to disk.

set -euo pipefail

SHARED_DIR="${HOME}/.agent-skills"
CLAUDE_SKILLS="${HOME}/.claude/skills"
CODEX_SKILLS="${HOME}/.codex/skills"
CLAUDE_AGENTS="${HOME}/.claude/agents"
CODEX_AGENTS="${HOME}/.codex/agents"

err() { echo "error: $*" >&2; exit 1; }
log() { echo "$*" >&2; }

URL=""
NAME=""
BRANCH=""
UPDATE=0
ONLY=""
LINK_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2;;
    --update) UPDATE=1; shift;;
    --only)   ONLY="$2"; shift 2;;
    --link-only) LINK_ONLY=1; shift;;
    -h|--help) sed -n '2,16p' "$0"; exit 0;;
    *)
      if [[ -z "$URL" ]]; then URL="$1"
      elif [[ -z "$NAME" ]]; then NAME="$1"
      else err "unexpected arg: $1"
      fi
      shift;;
  esac
done

[[ -z "$URL" && $UPDATE -eq 0 && $LINK_ONLY -eq 0 ]] && err "git url required"

if [[ ($UPDATE -eq 1 || $LINK_ONLY -eq 1) && -z "$NAME" && -n "$URL" && ! "$URL" =~ : ]]; then
  NAME="$URL"; URL=""
fi

derive_name() { basename "${1%.git}"; }

[[ -z "$NAME" && -n "$URL" ]] && NAME=$(derive_name "$URL")
[[ -z "$NAME" ]] && err "could not derive skill name"
[[ "$NAME" =~ ^[A-Za-z0-9._-]+$ ]] || err "invalid name: $NAME"

TARGET="$SHARED_DIR/$NAME"
mkdir -p "$SHARED_DIR" "$CLAUDE_SKILLS" "$CODEX_SKILLS" "$CLAUDE_AGENTS" "$CODEX_AGENTS"

git_with_creds() {
  if [[ -n "${GIT_TOKEN:-}" && -n "${GIT_USER:-}" ]]; then
    GIT_ASKPASS=/bin/true \
    git -c "credential.helper=!f(){ echo username=$GIT_USER; echo password=$GIT_TOKEN; };f" \
        "$@"
  else
    git "$@"
  fi
}

if [[ $LINK_ONLY -eq 1 ]]; then
  [[ -d "$TARGET" ]] || err "no clone at $TARGET — clone it first"
  log "linking existing clone at $TARGET"
elif [[ $UPDATE -eq 1 ]]; then
  [[ -d "$TARGET/.git" ]] || err "no install at $TARGET (run without --update first)"
  cd "$TARGET"
  if ! git diff --quiet || ! git diff --cached --quiet; then
    err "working tree at $TARGET is dirty — commit or discard before --update"
  fi
  log "updating $NAME at $TARGET"
  git_with_creds fetch --tags origin
  [[ -n "$BRANCH" ]] && git checkout "$BRANCH"
  git_with_creds pull --ff-only
else
  [[ -e "$TARGET" ]] && err "$TARGET already exists — use --update"
  [[ -z "$URL" ]] && err "git url required"
  log "cloning $URL → $TARGET"
  if [[ -n "$BRANCH" ]]; then
    git_with_creds clone --branch "$BRANCH" --single-branch "$URL" "$TARGET"
  else
    git_with_creds clone "$URL" "$TARGET"
  fi
fi

unset GIT_TOKEN GIT_USER

# Detect skill layout
SKILLS=()
if [[ -f "$TARGET/SKILL.md" ]]; then
  SKILLS+=("$NAME:$TARGET")
else
  for sub in "$TARGET"/*/; do
    [[ -d "$sub" ]] || continue
    [[ -f "$sub/SKILL.md" ]] || continue
    sub_name=$(basename "$sub")
    if [[ -n "$ONLY" && "$ONLY" != "$sub_name" ]]; then continue; fi
    SKILLS+=("$sub_name:${sub%/}")
  done
fi

[[ ${#SKILLS[@]} -gt 0 ]] || { rm -rf "$TARGET"; err "no SKILL.md found at root or in any subdir"; }

# Symlink each skill + its agents
INSTALLED=()
for entry in "${SKILLS[@]}"; do
  s_name="${entry%%:*}"
  s_path="${entry#*:}"

  ln -sfn "$s_path" "$CLAUDE_SKILLS/$s_name"
  ln -sfn "$s_path" "$CODEX_SKILLS/$s_name"

  if [[ -d "$s_path/agents" ]]; then
    for agent in "$s_path/agents/"*.md; do
      [[ -f "$agent" ]] || continue
      a_base=$(basename "$agent")
      ln -sfn "$agent" "$CLAUDE_AGENTS/$a_base"
      ln -sfn "$agent" "$CODEX_AGENTS/$a_base"
    done
  fi

  INSTALLED+=("$s_name")
done

VERSION=""
if [[ -f "$TARGET/VERSION" ]]; then
  VERSION=$(<"$TARGET/VERSION")
else
  VERSION=$(git -C "$TARGET" describe --tags --always 2>/dev/null || true)
fi

cat <<EOF
installed: ${INSTALLED[*]}
repo:      $TARGET
version:   ${VERSION:-unknown}
skills:
$(for s in "${INSTALLED[@]}"; do echo "  - $s → $CLAUDE_SKILLS/$s, $CODEX_SKILLS/$s"; done)
EOF

# Hint about post-install setup scripts
for entry in "${SKILLS[@]}"; do
  s_path="${entry#*:}"
  if [[ -x "$s_path/scripts/setup.sh" ]]; then
    s_name="${entry%%:*}"
    echo "  setup needed: $s_path/scripts/setup.sh    # for $s_name"
  fi
done
