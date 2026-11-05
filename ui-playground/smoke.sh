#!/bin/bash
set -euo pipefail
SOURCE=$(cd "$(dirname "$0")" && pwd)
QA=$(mktemp -d "${TMPDIR:-/tmp}/fabric-ui-qa.XXXXXX")
trap 'rm -rf "$QA"' EXIT
BIN="${FACTORIO_BIN:-$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio}"
[[ -x "$BIN" ]] || BIN=/Applications/factorio.app/Contents/MacOS/factorio
[[ -x "$BIN" ]] || { echo 'Set FACTORIO_BIN to your Factorio executable.'; exit 1; }
mkdir -p "$QA/mods" "$QA/scenarios"
ln -s "$SOURCE/mod" "$QA/mods/fabric-ui-playground"
cp -R "$SOURCE/tests/ui-smoke" "$QA/scenarios/ui-smoke"
cat > "$QA/config.ini" <<CONFIG
[path]
read-data=__PATH__system-read-data__
write-data=$QA
CONFIG
printf '%s\n' '{"mods":[{"name":"base","enabled":true},{"name":"fabric-ui-playground","enabled":true},{"name":"space-age","enabled":false},{"name":"quality","enabled":false},{"name":"elevated-rails","enabled":false}]}' > "$QA/mods/mod-list.json"
"$BIN" --config "$QA/config.ini" --mod-directory "$QA/mods" --test-scenario ui-smoke --test-ticks 120
