#!/bin/bash
set -euo pipefail
SOURCE=$(cd "$(dirname "$0")" && pwd)
LAB="${FABRIC_UI_HOME:-$HOME/fabric-ui-playground}"
BIN="${FACTORIO_BIN:-$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio}"
if [[ ! -x "$BIN" ]]; then BIN=/Applications/factorio.app/Contents/MacOS/factorio; fi
[[ -x "$BIN" ]] || { echo 'Set FACTORIO_BIN to your Factorio executable.'; exit 1; }
# Refuse a second launch while this isolated profile is already in use.
if [[ "${1:-}" != setup ]] && /usr/sbin/lsof -t "$LAB/.lock" >/dev/null 2>&1; then
  echo "Playground already running. Use its Reload button."
  exit 0
fi
mkdir -p "$LAB/mods" "$LAB/saves"
if [[ ! -f "$LAB/config.ini" ]]; then
cat > "$LAB/config.ini" <<CONFIG
[path]
read-data=__PATH__system-read-data__
write-data=$LAB
[general]
locale=en
[graphics]
full-screen=false
[interface]
show-tips-and-tricks=false
CONFIG
fi
if [[ ! -e "$LAB/mods/fabric-ui-playground" ]]; then ln -s "$SOURCE/mod" "$LAB/mods/fabric-ui-playground"; fi
cat > "$LAB/mods/mod-list.json" <<'MODS'
{"mods":[{"name":"base","enabled":true},{"name":"elevated-rails","enabled":false},{"name":"quality","enabled":false},{"name":"space-age","enabled":false},{"name":"recycler","enabled":false},{"name":"fabric-ui-playground","enabled":true}]}
MODS
args=(--config "$LAB/config.ini" --mod-directory "$LAB/mods")
if [[ ! -f "$LAB/saves/playground.zip" ]]; then
  "$BIN" "${args[@]}" --create "$LAB/saves/playground.zip" --map-gen-settings "$SOURCE/map-gen-settings.json" > "$LAB/create.log" 2>&1 || { cat "$LAB/create.log"; exit 1; }
fi
if [[ "${1:-}" == setup ]]; then echo "Ready: $LAB"; exit 0; fi
exec "$BIN" "${args[@]}" --load-game "$LAB/saves/playground.zip"
