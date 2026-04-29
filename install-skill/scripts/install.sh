#!/usr/bin/env bash
# Universal skill installer — clones a skill repo into the shared agent-skills
# layout and symlinks it into both Claude Code and Codex skill dirs.
#
# Usage:
#   install.sh <git-url> [name] [--branch <ref>] [--update]
#
# Auth (HTTPS private repos): set GIT_USER and GIT_TOKEN in env. They are used
# once via a transient credential helper and never written to disk.

set -euo pipefail

SHARED_DIR="${HOME}/.agent-skills"
CLAUDE_DIR="${HOME}/.claude/skills"
CODEX_DIR="${HOME}/.codex/skills"

err() { echo "error: $*" >&2; exit 1; }
log() { echo "$*" >&2; }

URL=""
NAME=""
BRANCH=""
UPDATE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2;;
    --update) UPDATE=1; shift;;
    -h|--help) sed -n '2,12p' "$0"; exit 0;;
    *)
      if [[ -z "$URL" ]]; then URL="$1"
      elif [[ -z "$NAME" ]]; then NAME="$1"
      else err "unexpected arg: $1"
      fi
      shift;;
  esac
done

[[ -z "$URL" && $UPDATE -eq 0 ]] && err "git url required"

# Update path: NAME is positional 1 instead of URL
if [[ $UPDATE -eq 1 && -z "$NAME" && -n "$URL" && ! "$URL" =~ : ]]; then
  NAME="$URL"; URL=""
fi

derive_name() {
  local u="$1"
  basename "${u%.git}"
}

[[ -z "$NAME" && -n "$URL" ]] && NAME=$(derive_name "$URL")
[[ -z "$NAME" ]] && err "could not derive skill name"
[[ "$NAME" =~ ^[A-Za-z0-9._-]+$ ]] || err "invalid skill name: $NAME"

TARGET="$SHARED_DIR/$NAME"
mkdir -p "$SHARED_DIR" "$CLAUDE_DIR" "$CODEX_DIR"

git_with_creds() {
  if [[ -n "${GIT_TOKEN:-}" && -n "${GIT_USER:-}" ]]; then
    GIT_ASKPASS=/bin/true \
    git -c "credential.helper=!f(){ echo username=$GIT_USER; echo password=$GIT_TOKEN; };f" \
        "$@"
  else
    git "$@"
  fi
}

if [[ $UPDATE -eq 1 ]]; then
  [[ -d "$TARGET/.git" ]] || err "no install at $TARGET (run without --update first)"
  cd "$TARGET"
  if ! git diff --quiet || ! git diff --cached --quiet; then
    err "working tree at $TARGET is dirty — commit or discard before --update"
  fi
  log "updating $NAME at $TARGET"
  git_with_creds fetch --tags origin
  if [[ -n "$BRANCH" ]]; then
    git checkout "$BRANCH"
  fi
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

# Scrub creds from env for the rest of the script
unset GIT_TOKEN GIT_USER

[[ -f "$TARGET/SKILL.md" ]] || { rm -rf "$TARGET"; err "no SKILL.md at repo root — not a skill"; }

ln -sfn "$TARGET" "$CLAUDE_DIR/$NAME"
ln -sfn "$TARGET" "$CODEX_DIR/$NAME"

VERSION=""
if [[ -f "$TARGET/VERSION" ]]; then
  VERSION=$(<"$TARGET/VERSION")
else
  VERSION=$(git -C "$TARGET" describe --tags --always 2>/dev/null || true)
fi

DESC=$(awk '/^description:/{found=1; sub(/^description:[[:space:]]*/,""); if(length($0)){print; exit}; next} found && /^[[:space:]]+/ {sub(/^[[:space:]]+/,""); print; exit}' "$TARGET/SKILL.md" | tr -d '>' | sed 's/^[[:space:]]*//')

cat <<EOF
installed: $NAME
version:   ${VERSION:-unknown}
source:    $TARGET
claude:    $CLAUDE_DIR/$NAME -> $TARGET
codex:     $CODEX_DIR/$NAME -> $TARGET
description: ${DESC:-(none)}
EOF
