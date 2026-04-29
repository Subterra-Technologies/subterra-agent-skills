#!/usr/bin/env bash
# Docmost API wrapper for the /notes skill.
# Reads connection from ~/.docmost/config (set by setup.sh) or env vars.
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

API_BASE="${DOCMOST_URL:-http://localhost:3000}"
TOKEN_FILE="${DOCMOST_TOKEN_FILE:-${HOME}/.docmost/token}"
EMAIL="${DOCMOST_EMAIL:-}"

err() { echo "error: $*" >&2; exit 1; }

token() {
  [[ -s "$TOKEN_FILE" ]] || err "no token at $TOKEN_FILE — run scripts/setup.sh"
  cat "$TOKEN_FILE"
}

call() {
  local path="$1" body="$2"
  local t; t=$(token)
  local resp; resp=$(curl -s -X POST "$API_BASE/api$path" \
    -H "Cookie: authToken=$t" \
    -H "Content-Type: application/json" \
    -d "$body")
  if echo "$resp" | grep -q '"statusCode":401'; then
    err "401 — token invalid. Re-run scripts/setup.sh"
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
print(json.dumps({"pageId":sys.argv[1],"operation":sys.argv[2],"content":content}))' "$pid" "$op" "$file")
    call /pages/update "$body"
    ;;
  *)
    echo "usage: notes.sh {spaces|search|info|children|create|update} ..." >&2
    exit 2
    ;;
esac
