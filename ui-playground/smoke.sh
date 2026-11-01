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
cp -R "$SOURCE/tests/ui-integration" "$QA/scenarios/ui-integration"
cp -R "$SOURCE/tests/test-driver" "$QA/mods/fabric-ui-test-driver"
cat > "$QA/config.ini" <<CONFIG
[path]
read-data=__PATH__system-read-data__
write-data=$QA
CONFIG
python3 "$SOURCE/prepare-mods.py" "$QA"
python3 - "$QA/mods/mod-list.json" <<'PYMOD'
import json,sys
p=sys.argv[1];j=json.load(open(p));j['mods'].append({'name':'fabric-ui-test-driver','enabled':True});open(p,'w').write(json.dumps(j))
PYMOD
if [[ "${1:-}" != integration && "${1:-}" != persistence ]]; then
  "$BIN" --config "$QA/config.ini" --mod-directory "$QA/mods" --test-scenario ui-smoke --test-arg unit --test-ticks 1200
fi
if [[ "${1:-}" != persistence ]]; then
  "$BIN" --config "$QA/config.ini" --mod-directory "$QA/mods" --test-scenario ui-integration --test-ticks 1200
fi
if [[ -n "${FABRIC_TEST_SAVE:-}" ]]; then
  "$BIN" --config "$QA/config.ini" --mod-directory "$QA/mods" --test-save "$FABRIC_TEST_SAVE" --test-arg persistence --test-ticks 180
fi
