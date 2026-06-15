#!/usr/bin/env bash
#
# claude-profile — switch the Claude Code login between accounts (e.g. personal / company).
#
# Claude Code stores the logged-in identity in two files:
#   ~/.claude/.credentials.json   OAuth tokens (claudeAiOauth)
#   ~/.claude.json                oauthAccount / userID / organizationUuid  (+ unrelated state)
#
# This script snapshots those bits per named profile and swaps them in/out, leaving the
# rest of ~/.claude.json (project history, settings, etc.) untouched.
#
# Usage:
#   claude-profile save <name>      Save the current login as profile <name>
#   claude-profile switch <name>    Activate profile <name>
#   claude-profile list             List saved profiles (* = active)
#   claude-profile current          Show the currently logged-in account
#   claude-profile delete <name>    Remove a saved profile
#
# Quit Claude Code before switching; restart it afterwards.

set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CONFIG_JSON="${CLAUDE_CONFIG:-$HOME/.claude.json}"
CRED_JSON="$CLAUDE_HOME/.credentials.json"
PROFILE_DIR="$CLAUDE_HOME/profiles"

# Keys in ~/.claude.json that identify the account.
ACCOUNT_KEYS='["oauthAccount","userID","organizationUuid"]'

die() { echo "error: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || die "python3 is required"

usage() {
  awk 'NR>2 && /^#/ {sub(/^# ?/,""); print; next} NR>2 {exit}' "$0"
  exit "${1:-0}"
}

# Pull the account-identifying keys out of ~/.claude.json into a small JSON file.
extract_account() { # <out_file>
  python3 - "$CONFIG_JSON" "$1" "$ACCOUNT_KEYS" <<'PY'
import json, sys
src, out, keys = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
data = json.load(open(src))
picked = {k: data[k] for k in keys if k in data}
if not picked:
    sys.exit("no account keys found in %s — are you logged in?" % src)
json.dump(picked, open(out, "w"), indent=2)
PY
}

# Merge a saved account snapshot back into ~/.claude.json (preserving everything else).
merge_account() { # <account_file>
  python3 - "$CONFIG_JSON" "$1" "$ACCOUNT_KEYS" <<'PY'
import json, sys, os
cfg, acct_file, keys = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
data = json.load(open(cfg)) if os.path.exists(cfg) else {}
acct = json.load(open(acct_file))
for k in keys:
    data.pop(k, None)
data.update({k: v for k, v in acct.items() if k in keys})
tmp = cfg + ".tmp"
json.dump(data, open(tmp, "w"), indent=2)
os.replace(tmp, cfg)
PY
}

show_account() { # <config_or_account_file>
  python3 - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
a = d.get("oauthAccount", d)
print("  email :", a.get("emailAddress", "?"))
print("  name  :", a.get("displayName", "?"))
print("  org   :", a.get("organizationName", "?"))
print("  role  :", a.get("organizationRole", "?"))
PY
}

# Marker so `list` can show which profile is active (matched by org+email).
active_fingerprint() {
  [ -f "$CONFIG_JSON" ] || return 0
  python3 - "$CONFIG_JSON" <<'PY'
import json, sys
a = json.load(open(sys.argv[1])).get("oauthAccount", {})
print("%s|%s" % (a.get("organizationUuid",""), a.get("emailAddress","")))
PY
}

profile_fingerprint() { # <name>
  local f="$PROFILE_DIR/$1/account.json"
  [ -f "$f" ] || return 0
  python3 - "$f" <<'PY'
import json, sys
a = json.load(open(sys.argv[1])).get("oauthAccount", {})
print("%s|%s" % (a.get("organizationUuid",""), a.get("emailAddress","")))
PY
}

cmd_save() {
  local name="${1:-}"; [ -n "$name" ] || die "usage: claude-profile save <name>"
  [ -f "$CRED_JSON" ] || die "no credentials at $CRED_JSON — log in with 'claude' first"
  local dir="$PROFILE_DIR/$name"
  mkdir -p "$dir"
  cp "$CRED_JSON" "$dir/.credentials.json"
  chmod 600 "$dir/.credentials.json"
  extract_account "$dir/account.json"
  echo "saved profile '$name':"
  show_account "$dir/account.json"
}

cmd_switch() {
  local name="${1:-}"; [ -n "$name" ] || die "usage: claude-profile switch <name>"
  local dir="$PROFILE_DIR/$name"
  [ -d "$dir" ] || die "no such profile: $name (try 'claude-profile list')"
  [ -f "$dir/.credentials.json" ] || die "profile '$name' has no saved credentials"
  [ -f "$dir/account.json" ] || die "profile '$name' has no saved account info"

  # Back up whatever is active now so a bad switch is recoverable.
  local ts; ts="$(date +%Y%m%d-%H%M%S)"
  local bak="$PROFILE_DIR/.backup-$ts"
  mkdir -p "$bak"
  [ -f "$CRED_JSON" ] && cp "$CRED_JSON" "$bak/.credentials.json"
  [ -f "$CONFIG_JSON" ] && cp "$CONFIG_JSON" "$bak/.claude.json"

  cp "$dir/.credentials.json" "$CRED_JSON"
  chmod 600 "$CRED_JSON"
  merge_account "$dir/account.json"

  echo "switched to profile '$name':"
  show_account "$dir/account.json"
  echo "(backup of previous login: $bak)"
  echo "restart Claude Code to apply."
}

cmd_list() {
  [ -d "$PROFILE_DIR" ] || { echo "no profiles saved yet"; return 0; }
  local active; active="$(active_fingerprint)"
  local found=0
  for dir in "$PROFILE_DIR"/*/; do
    [ -d "$dir" ] || continue
    local name; name="$(basename "$dir")"
    case "$name" in .backup-*) continue;; esac
    found=1
    local mark="  "
    [ -n "$active" ] && [ "$(profile_fingerprint "$name")" = "$active" ] && mark="* "
    echo "${mark}${name}"
  done
  [ "$found" -eq 0 ] && echo "no profiles saved yet"
}

cmd_current() {
  [ -f "$CONFIG_JSON" ] || die "no $CONFIG_JSON found"
  echo "currently logged in as:"
  show_account "$CONFIG_JSON"
}

cmd_delete() {
  local name="${1:-}"; [ -n "$name" ] || die "usage: claude-profile delete <name>"
  local dir="$PROFILE_DIR/$name"
  [ -d "$dir" ] || die "no such profile: $name"
  rm -rf "$dir"
  echo "deleted profile '$name'"
}

case "${1:-}" in
  save)    shift; cmd_save "$@";;
  switch)  shift; cmd_switch "$@";;
  list|ls) cmd_list;;
  current) cmd_current;;
  delete|rm) shift; cmd_delete "$@";;
  -h|--help|help|"") usage 0;;
  *) die "unknown command: $1 (try --help)";;
esac
