#!/usr/bin/env bash
# Text a URL to the user's own Apple ID so the link is waiting on the iPad.
# No-op when imessage_to is not configured. Usage: send-imessage.sh <url> [message]
set -euo pipefail
URL="$1"
MSG="${2:-device-it install link}"
TO=$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.device-it/config.json"))).get("imessage_to",""))' 2>/dev/null || true)
[[ -z "$TO" ]] && { echo "imessage: skipped (imessage_to not configured)"; exit 0; }
osascript <<EOF
tell application "Messages"
  set svc to 1st account whose service type = iMessage
  set buddyRef to participant "$TO" of svc
  send "$MSG: $URL" to buddyRef
end tell
EOF
echo "imessage: sent to $TO"
