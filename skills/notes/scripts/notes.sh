#!/usr/bin/env bash
# Docmost API wrapper for the /notes skill.
# Reads connection from ~/.docmost/config (set by setup.sh) or env vars.
# Auth: Bearer API key (Docmost → Settings → API keys). No user account.
#
# Usage:
#   notes.sh spaces
#   notes.sh search <query>
#   notes.sh info <pageId>
#   notes.sh children <spaceId|pageId>
#   notes.sh create <spaceId> <parentPageId|""> <title>
#   notes.sh update <pageId> <append|replace> <contentFile>

set -euo pipefail

CONFIG="${HOME}/.docmost/config"
[[ -f "$CONFIG" ]] && source "$CONFIG"

API_BASE="${DOCMOST_URL:-https://docs.example.com}"
KEY_FILE="${DOCMOST_API_KEY_FILE:-${HOME}/.docmost/api-key}"

err() { echo "error: $*" >&2; exit 1; }

key() {
  [[ -s "$KEY_FILE" ]] || err "no API key at $KEY_FILE — run scripts/setup.sh"
  cat "$KEY_FILE"
}

call() {
  local path="$1" body="$2"
  local k; k=$(key)
  local resp; resp=$(curl -s "$API_BASE/api$path" \
    -X POST \
    -H "Authorization: Bearer $k" \
    -H "Content-Type: application/json" \
    -d "$body")
  if echo "$resp" | grep -q '"statusCode":401\|"statusCode":403'; then
    err "auth rejected — API key revoked or expired. Re-run scripts/setup.sh"
  fi
  echo "$resp"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  spaces)
    call /spaces '{}'
    ;;
  search)
    q="$*"
    call /search "$(python3 -c 'import json,sys;print(json.dumps({"query":sys.argv[1]}))' "$q")"
    ;;
  info)
    call /pages/info "$(python3 -c 'import json,sys;print(json.dumps({"pageId":sys.argv[1]}))' "$1")"
    ;;
  children)
    id="$1"
    out=$(call /pages/sidebar-pages "$(python3 -c 'import json,sys;print(json.dumps({"spaceId":sys.argv[1]}))' "$id")")
    if echo "$out" | grep -q '"items":\[\]\|"error"'; then
      out=$(call /pages/sidebar-pages "$(python3 -c 'import json,sys;print(json.dumps({"pageId":sys.argv[1]}))' "$id")")
    fi
    echo "$out"
    ;;
  create)
    space="$1"; parent="${2:-}"; title="$3"
    body=$(python3 -c '
import json,sys
d={"spaceId":sys.argv[1],"title":sys.argv[3]}
if sys.argv[2]: d["parentPageId"]=sys.argv[2]
print(json.dumps(d))' "$space" "$parent" "$title")
    call /pages/create "$body"
    ;;
  update)
    pid="$1"; op="$2"; file="$3"
    body=$(python3 -c '
import json,sys
content=open(sys.argv[3]).read()
print(json.dumps({"pageId":sys.argv[1],"operation":sys.argv[2],"format":"markdown","content":content}))' "$pid" "$op" "$file")
    call /pages/update "$body"
    ;;
  *)
    echo "usage: notes.sh {spaces|search|info|children|create|update} ..." >&2
    exit 2
    ;;
esac
