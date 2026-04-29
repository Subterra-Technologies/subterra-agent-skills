#!/usr/bin/env bash
# Interactive first-time setup for the /notes skill.
# Configures Docmost connection using an API key (Bearer auth — no user
# account credentials), discovers spaces, optionally creates the AI Notes
# Agent area, writes references/config.local.md, and symlinks the subagent
# definition into ~/.claude/agents/ and ~/.codex/agents/.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
CONFIG_DIR="${HOME}/.docmost"
KEY_FILE="${CONFIG_DIR}/api-key"
ENV_FILE="${CONFIG_DIR}/config"
LOCAL_CONFIG="${SKILL_DIR}/references/config.local.md"

REFRESH=0
[[ "${1:-}" == "--refresh" ]] && REFRESH=1

err() { echo "error: $*" >&2; exit 1; }
ask() { local prompt="$1" def="${2:-}" v; read -rp "$prompt${def:+ [$def]}: " v || true; echo "${v:-$def}"; }
ask_secret() { local prompt="$1" v; read -rsp "$prompt: " v; echo >&2; echo "$v"; }

# Arrow-key single-select. Usage: pick_one "Prompt" opt1 opt2 ...
# Echoes chosen option to stdout. Falls back to first option if non-tty.
pick_one() {
  local prompt="$1"; shift
  local opts=("$@") n=${#@} sel=0 i key key2
  if ! [[ -t 0 && -t 2 ]]; then printf "%s\n" "${opts[0]}"; return; fi
  printf "%s (↑/↓, Enter)\n" "$prompt" >&2
  tput civis 2>/dev/null || true
  for ((i=0; i<n; i++)); do printf "\n" >&2; done
  while true; do
    printf "\033[%dA" "$n" >&2
    for ((i=0; i<n; i++)); do
      if (( i == sel )); then
        printf "\033[2K\r\033[7m> %s\033[0m\n" "${opts[i]}" >&2
      else
        printf "\033[2K\r  %s\n" "${opts[i]}" >&2
      fi
    done
    IFS= read -rsn1 key
    if [[ $key == $'\x1b' ]]; then read -rsn2 -t 0.01 key2 || true; key+=${key2:-}; fi
    case "$key" in
      $'\x1b[A'|k) (( sel = (sel - 1 + n) % n ));;
      $'\x1b[B'|j) (( sel = (sel + 1) % n ));;
      "") tput cnorm 2>/dev/null || true; printf "%s\n" "${opts[sel]}"; return;;
      q) tput cnorm 2>/dev/null || true; return 1;;
    esac
  done
}

# Arrow-key multi-select. Usage: pick_many "Prompt" opt1 opt2 ...
# Echoes chosen options (one per line). All on by default. Space toggles, Enter confirms.
pick_many() {
  local prompt="$1"; shift
  local opts=("$@") n=${#@} sel=0 i key key2
  local checked=()
  for ((i=0; i<n; i++)); do checked[i]=1; done
  if ! [[ -t 0 && -t 2 ]]; then for o in "${opts[@]}"; do printf "%s\n" "$o"; done; return; fi
  printf "%s (↑/↓, Space, Enter)\n" "$prompt" >&2
  tput civis 2>/dev/null || true
  for ((i=0; i<n; i++)); do printf "\n" >&2; done
  while true; do
    printf "\033[%dA" "$n" >&2
    for ((i=0; i<n; i++)); do
      local mark="[ ]"; [[ ${checked[i]} -eq 1 ]] && mark="[x]"
      if (( i == sel )); then
        printf "\033[2K\r\033[7m> %s %s\033[0m\n" "$mark" "${opts[i]}" >&2
      else
        printf "\033[2K\r  %s %s\n" "$mark" "${opts[i]}" >&2
      fi
    done
    IFS= read -rsn1 key
    if [[ $key == $'\x1b' ]]; then read -rsn2 -t 0.01 key2 || true; key+=${key2:-}; fi
    case "$key" in
      $'\x1b[A'|k) (( sel = (sel - 1 + n) % n ));;
      $'\x1b[B'|j) (( sel = (sel + 1) % n ));;
      " ") checked[sel]=$(( 1 - checked[sel] ));;
      "") tput cnorm 2>/dev/null || true
          for ((i=0; i<n; i++)); do [[ ${checked[i]} -eq 1 ]] && printf "%s\n" "${opts[i]}"; done
          return;;
      q) tput cnorm 2>/dev/null || true; return 1;;
    esac
  done
}

mkdir -p "$CONFIG_DIR"

echo "=== /notes skill setup ==="

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

DOCMOST_URL="${DOCMOST_URL:-}"
DOCMOST_URL=$(ask "Docmost base URL" "${DOCMOST_URL:-https://docs.example.com}")

echo
echo "Get an API key from Docmost:"
echo "  1. Open ${DOCMOST_URL%/}/settings/api-keys (or Settings → Account → API keys)"
echo "  2. Click 'Create API Key', name it (e.g. notes-skill)"
echo "  3. Copy the key — Docmost shows it once only"
echo

REUSE=0
if [[ -s "$KEY_FILE" ]]; then
  if curl -fsS "$DOCMOST_URL/api/spaces" \
       -X POST \
       -H "Authorization: Bearer $(cat "$KEY_FILE")" \
       -H "Content-Type: application/json" \
       -d '{}' >/dev/null 2>&1; then
    if [[ "$(ask "Existing API key at $KEY_FILE works. Reuse? (Y/n)" "Y")" =~ ^[Yy] ]]; then
      REUSE=1
    fi
  fi
fi

if [[ $REUSE -eq 0 ]]; then
  KEY=$(ask_secret "Paste API key")
  [[ -n "$KEY" ]] || err "no key provided"

  if ! curl -fsS "$DOCMOST_URL/api/spaces" \
       -X POST \
       -H "Authorization: Bearer $KEY" \
       -H "Content-Type: application/json" \
       -d '{}' >/dev/null 2>&1; then
    err "API key rejected by $DOCMOST_URL — check the key and try again"
  fi

  printf '%s' "$KEY" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  unset KEY
  echo "key saved to $KEY_FILE"
fi

{
  echo "DOCMOST_URL=$DOCMOST_URL"
  echo "DOCMOST_API_KEY_FILE=$KEY_FILE"
} > "$ENV_FILE"
chmod 600 "$ENV_FILE"

KEY=$(cat "$KEY_FILE")

api() {
  local path="$1" body="${2:-{\}}"
  curl -fsS "$DOCMOST_URL/api$path" \
    -X POST \
    -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    -d "$body"
}

echo
echo "discovering spaces..."
SPACES_JSON=$(api /spaces '{}')

# Build parallel arrays of space names + IDs
mapfile -t SPACE_NAMES < <(SPACES_JSON="$SPACES_JSON" python3 <<'PY'
import json, os
d = json.loads(os.environ["SPACES_JSON"])
for s in d.get("data", {}).get("items", []): print(s["name"])
PY
)
mapfile -t SPACE_IDS < <(SPACES_JSON="$SPACES_JSON" python3 <<'PY'
import json, os
d = json.loads(os.environ["SPACES_JSON"])
for s in d.get("data", {}).get("items", []): print(s["id"])
PY
)
[[ ${#SPACE_NAMES[@]} -gt 0 ]] || err "no spaces returned from Docmost"

echo
INBOX_SPACE_NAME=$(pick_one "Which space should host the AI Notes Agent inbox?" "${SPACE_NAMES[@]}")
INBOX_SPACE_ID=""
for i in "${!SPACE_NAMES[@]}"; do
  [[ "${SPACE_NAMES[i]}" == "$INBOX_SPACE_NAME" ]] && INBOX_SPACE_ID="${SPACE_IDS[i]}" && break
done
[[ -n "$INBOX_SPACE_ID" ]] || err "space '$INBOX_SPACE_NAME' not found"
echo "  → $INBOX_SPACE_NAME ($INBOX_SPACE_ID)"

CREATE_AREA=$(ask "Create 'AI Notes Agent' parent + subpages in $INBOX_SPACE_NAME? (y/N)" "N")
AGENT_AREA_PARENT_ID=""
OR_ID=""; FRL_ID=""; INBOX_ID=""; PI_ID=""

if [[ "$CREATE_AREA" =~ ^[Yy] ]]; then
  PARENT_PATH=$(ask "Optional: existing parent page ID inside $INBOX_SPACE_NAME (blank = top level)" "")

  echo
  mapfile -t PICKED_CHILDREN < <(pick_many "Which subpages to create?" \
    "Operating Rules" "Filing Rules Learned" "Inbox / Needs Review" "Proposed Improvements")
  if [[ ${#PICKED_CHILDREN[@]} -eq 0 ]]; then
    echo "  no subpages selected — skipping AI Notes Agent area"
  else
    body=$(python3 -c '
import json, sys
d = {"spaceId": sys.argv[1], "title": "AI Notes Agent"}
if sys.argv[2]: d["parentPageId"] = sys.argv[2]
print(json.dumps(d))' "$INBOX_SPACE_ID" "$PARENT_PATH")
    resp=$(api /pages/create "$body")
    AGENT_AREA_PARENT_ID=$(echo "$resp" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("id") or d.get("data",{}).get("id"))')
    echo "  AI Notes Agent → $AGENT_AREA_PARENT_ID"

    for child in "${PICKED_CHILDREN[@]}"; do
      body=$(python3 -c 'import json,sys;print(json.dumps({"spaceId":sys.argv[1],"parentPageId":sys.argv[2],"title":sys.argv[3]}))' \
        "$INBOX_SPACE_ID" "$AGENT_AREA_PARENT_ID" "$child")
      resp=$(api /pages/create "$body")
      cid=$(echo "$resp" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("id") or d.get("data",{}).get("id"))')
      echo "    $child → $cid"
      case "$child" in
        "Operating Rules")        OR_ID="$cid";;
        "Filing Rules Learned")   FRL_ID="$cid";;
        "Inbox / Needs Review")   INBOX_ID="$cid";;
        "Proposed Improvements")  PI_ID="$cid";;
      esac
    done
  fi
fi

echo
echo "writing $LOCAL_CONFIG"

SPACES_YAML=$(SPACES_JSON="$SPACES_JSON" python3 <<'PY'
import json, os
d = json.loads(os.environ["SPACES_JSON"])
print("spaces:")
for s in d.get("data", {}).get("items", []):
    print(f"  {s['name']}: \"{s['id']}\"")
PY
)

LINK_BASE=$(ask "Public link base for sharing (e.g. https://docs.example.com)" "$DOCMOST_URL")

cat > "$LOCAL_CONFIG" <<EOF
# Notes Skill — Local Config (auto-generated by setup.sh)
# Gitignored. Do not commit.

api_base: "$DOCMOST_URL"
link_base: "$LINK_BASE"
api_key_file: "$KEY_FILE"

$SPACES_YAML

agent_area:
  parent_id: "${AGENT_AREA_PARENT_ID}"
  pages:
    operating_rules:       "${OR_ID}"
    filing_rules_learned:  "${FRL_ID}"
    inbox:                 "${INBOX_ID}"
    proposed_improvements: "${PI_ID}"

# Cached entity lists. Run setup.sh --refresh to repopulate.
known_clients_active: []
known_clients_discussion: []
known_internal_tools: []
routing_exceptions: {}

parents: {}
EOF

chmod 600 "$LOCAL_CONFIG"

for AGENT_DIR in "$HOME/.claude/agents" "$HOME/.codex/agents"; do
  mkdir -p "$AGENT_DIR"
  ln -sfn "$SKILL_DIR/agents/notes-librarian.md" "$AGENT_DIR/notes-librarian.md"
  echo "linked: $AGENT_DIR/notes-librarian.md"
done

echo
echo "=== setup complete ==="
echo "  config.local.md: $LOCAL_CONFIG"
echo "  env:             $ENV_FILE"
echo "  api key:         $KEY_FILE (chmod 600, Bearer auth)"
[[ -n "$INBOX_ID" ]] && echo "  inbox page id:   $INBOX_ID"
echo
echo "Try it: /notes save this"
echo "Rotate any time: revoke in Docmost → Settings → API keys, re-run this script."
