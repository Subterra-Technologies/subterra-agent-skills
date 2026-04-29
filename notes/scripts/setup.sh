#!/usr/bin/env bash
# Interactive first-time setup for the /notes skill.
# Configures Docmost connection, optionally creates the AI Notes Agent area,
# writes references/config.local.md with discovered IDs, and symlinks the
# subagent definition into ~/.claude/agents/ and ~/.codex/agents/.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="${HOME}/.docmost"
TOKEN_FILE="${CONFIG_DIR}/token"
ENV_FILE="${CONFIG_DIR}/config"
LOCAL_CONFIG="${SKILL_DIR}/references/config.local.md"

REFRESH=0
[[ "${1:-}" == "--refresh" ]] && REFRESH=1

err() { echo "error: $*" >&2; exit 1; }
ask() { local prompt="$1" def="${2:-}" v; read -rp "$prompt${def:+ [$def]}: " v || true; echo "${v:-$def}"; }
ask_secret() { local prompt="$1" v; read -rsp "$prompt: " v; echo >&2; echo "$v"; }

mkdir -p "$CONFIG_DIR"

echo "=== /notes skill setup ==="

# Load existing
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

DOCMOST_URL="${DOCMOST_URL:-}"
DOCMOST_EMAIL="${DOCMOST_EMAIL:-}"

DOCMOST_URL=$(ask "Docmost base URL" "${DOCMOST_URL:-http://localhost:3000}")
DOCMOST_EMAIL=$(ask "Agent account email" "${DOCMOST_EMAIL:-}")

# Token: reuse if present and valid, else login
NEED_LOGIN=1
if [[ -s "$TOKEN_FILE" ]]; then
  if curl -fsS -X POST "$DOCMOST_URL/api/spaces" \
       -H "Cookie: authToken=$(cat "$TOKEN_FILE")" \
       -H "Content-Type: application/json" \
       -d '{}' >/dev/null 2>&1; then
    echo "existing token at $TOKEN_FILE works — reusing"
    NEED_LOGIN=0
  fi
fi

if [[ $NEED_LOGIN -eq 1 ]]; then
  PASS=$(ask_secret "Password for $DOCMOST_EMAIL")
  echo "logging in..."
  resp=$(curl -fsS -X POST "$DOCMOST_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c 'import json,sys;print(json.dumps({"email":sys.argv[1],"password":sys.argv[2]}))' "$DOCMOST_EMAIL" "$PASS")" \
    -D - 2>&1)
  TOKEN=$(echo "$resp" | grep -i 'set-cookie: authToken=' | sed 's/.*authToken=//;s/;.*//' | tr -d '\r')
  [[ -n "$TOKEN" ]] || err "login failed"
  printf '%s' "$TOKEN" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  unset PASS
  echo "token saved to $TOKEN_FILE"
fi

# Persist non-secret config
{
  echo "DOCMOST_URL=$DOCMOST_URL"
  echo "DOCMOST_EMAIL=$DOCMOST_EMAIL"
  echo "DOCMOST_TOKEN_FILE=$TOKEN_FILE"
} > "$ENV_FILE"
chmod 600 "$ENV_FILE"

TOKEN=$(cat "$TOKEN_FILE")

api() {
  local path="$1" body="${2:-{\}}"
  curl -fsS -X POST "$DOCMOST_URL/api$path" \
    -H "Cookie: authToken=$TOKEN" \
    -H "Content-Type: application/json" \
    -d "$body"
}

echo
echo "discovering spaces..."
SPACES_JSON=$(api /spaces '{}')
echo "$SPACES_JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
items = d.get("data", {}).get("items", [])
for i, s in enumerate(items, 1):
    print(f"  {i}. {s[\"name\"]:30} {s[\"id\"]}")
'

# Pick the inbox parent space
echo
INBOX_SPACE_NAME=$(ask "Which space should host the AI Notes Agent inbox?" "Projects")
INBOX_SPACE_ID=$(echo "$SPACES_JSON" | python3 -c '
import json, sys
target = sys.argv[1]
d = json.load(sys.stdin)
for s in d.get("data", {}).get("items", []):
    if s["name"].lower() == target.lower():
        print(s["id"]); break
' "$INBOX_SPACE_NAME")
[[ -n "$INBOX_SPACE_ID" ]] || err "space '$INBOX_SPACE_NAME' not found"

# Optional: create AI Notes Agent area
CREATE_AREA=$(ask "Create 'AI Notes Agent' parent + subpages in $INBOX_SPACE_NAME? (y/N)" "N")
AGENT_AREA_PARENT_ID=""
OR_ID=""; FRL_ID=""; INBOX_ID=""; PI_ID=""

if [[ "$CREATE_AREA" =~ ^[Yy] ]]; then
  PARENT_PATH=$(ask "Optional: existing parent page ID inside $INBOX_SPACE_NAME (blank = top level)" "")
  body=$(python3 -c '
import json, sys
d = {"spaceId": sys.argv[1], "title": "AI Notes Agent"}
if sys.argv[2]: d["parentPageId"] = sys.argv[2]
print(json.dumps(d))' "$INBOX_SPACE_ID" "$PARENT_PATH")
  resp=$(api /pages/create "$body")
  AGENT_AREA_PARENT_ID=$(echo "$resp" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("id") or d.get("data",{}).get("id"))')
  echo "  AI Notes Agent → $AGENT_AREA_PARENT_ID"

  for child in "Operating Rules" "Filing Rules Learned" "Inbox / Needs Review" "Proposed Improvements"; do
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

# Write config.local.md
echo
echo "writing $LOCAL_CONFIG"

SPACES_YAML=$(echo "$SPACES_JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print("spaces:")
for s in d.get("data", {}).get("items", []):
    print(f"  {s[\"name\"]}: \"{s[\"id\"]}\"")
')

LINK_BASE=$(ask "Public link base for sharing (e.g. https://docs.example.com)" "$DOCMOST_URL")

cat > "$LOCAL_CONFIG" <<EOF
# Notes Skill — Local Config (auto-generated by setup.sh)
# This file is gitignored. Do not commit.

api_base: "$DOCMOST_URL"
link_base: "$LINK_BASE"
token_file: "$TOKEN_FILE"
email: "$DOCMOST_EMAIL"

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

# Symlink subagent into agent dirs
for AGENT_DIR in "$HOME/.claude/agents" "$HOME/.codex/agents"; do
  mkdir -p "$AGENT_DIR"
  ln -sfn "$SKILL_DIR/agents/notes-librarian.md" "$AGENT_DIR/notes-librarian.md"
  echo "linked: $AGENT_DIR/notes-librarian.md"
done

echo
echo "=== setup complete ==="
echo "  config.local.md: $LOCAL_CONFIG"
echo "  env:             $ENV_FILE"
echo "  token:           $TOKEN_FILE"
[[ -n "$INBOX_ID" ]] && echo "  inbox page id:   $INBOX_ID"
echo
echo "Try it: /notes save this"
