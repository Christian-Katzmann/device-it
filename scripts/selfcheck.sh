#!/usr/bin/env bash
# Repo self-check: every script parses, every manifest is valid, templates are well-formed.
# No network, no deploys — safe to run anywhere (macOS + Linux; this is what CI runs).
set -uo pipefail
cd "$(dirname "$0")/.."
FAIL=0

while IFS= read -r f; do
  bash -n "$f" && echo "ok  bash   $f" || { echo "BAD bash   $f"; FAIL=1; }
done < <(find scripts -name '*.sh' | sort)

while IFS= read -r f; do
  node --check "$f" >/dev/null && echo "ok  node   $f" || { echo "BAD node   $f"; FAIL=1; }
done < <(find scripts -name '*.mjs' | sort)

for j in package.json .claude-plugin/plugin.json .codex-plugin/plugin.json; do
  node -e "JSON.parse(require('fs').readFileSync('$j','utf8'))" \
    && echo "ok  json   $j" || { echo "BAD json   $j"; FAIL=1; }
done

for t in templates/webclip.mobileconfig.tpl templates/enroll.mobileconfig.tpl; do
  python3 -c "import xml.dom.minidom; xml.dom.minidom.parse('$t')" \
    && echo "ok  xml    $t" || { echo "BAD xml    $t"; FAIL=1; }
done

echo
[[ $FAIL -eq 0 ]] && echo "selfcheck: all green" || echo "selfcheck: FAILURES above"
exit $FAIL
