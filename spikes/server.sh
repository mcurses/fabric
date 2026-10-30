#!/bin/bash
# Local headless Factorio for Fabric's design spikes. Never touches the player's own install, saves or mods.
#   spikes/server.sh start   fresh map, start in the background (UDP 34410, RCON 127.0.0.1:27410, password "spike")
#   spikes/server.sh resume  save, stop and load the same map again
#   spikes/server.sh stop    stop the run whose pid is in server.pid
set -euo pipefail
DIR="$HOME/fabric-spike"
BIN="/Applications/factorio.app/Contents/MacOS/factorio"
mkdir -p "$DIR/mods" "$DIR/saves"

stop() {
  if [[ -f "$DIR/server.pid" ]]; then
    pid=$(cat "$DIR/server.pid")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
      for _ in $(seq 60); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
      kill -0 "$pid" 2>/dev/null && kill -9 "$pid"
    fi
    rm -f "$DIR/server.pid"
  fi
}

launch() {
    nohup "$BIN" --config "$DIR/config.ini" --mod-directory "$DIR/mods" --start-server "$DIR/saves/spike.zip" \
      --server-settings "$DIR/server-settings.json" --port 34410 --rcon-port 27410 --rcon-password spike \
      > "$DIR/server.log" 2>&1 < /dev/null &
    echo $! > "$DIR/server.pid"
    for _ in $(seq 120); do grep -q "RCON interface at" "$DIR/server.log" 2>/dev/null && break; sleep 1; done
    grep -q "RCON interface at" "$DIR/server.log" || { tail -20 "$DIR/server.log"; exit 1; }
    # The first Lua command of a run only triggers the "achievements will be disabled" notice; spend it here.
    "$(dirname "$0")/rcon.py" - <<< 'rcon.print(1)' > /dev/null
    echo "running, pid $(cat "$DIR/server.pid")"
}

case "${1:-}" in
  stop) stop ;;
  resume)
    # Save, stop and load the same map again (save/reload checks).
    "$(dirname "$0")/rcon.py" - <<< '/server-save' > /dev/null
    sleep 3
    stop
    launch
    ;;
  start)
    stop
    cat > "$DIR/config.ini" <<EOF
[path]
read-data=__PATH__system-read-data__
write-data=$DIR
EOF
    python3 - "$DIR/server-settings.json" <<'PY'
import json, sys
s = json.load(open("/Applications/factorio.app/Contents/data/server-settings.example.json"))
s.update({"name": "fabric-spike", "description": "Fabric design spikes", "visibility": {"public": False, "lan": False},
          "require_user_verification": False, "auto_pause": False, "autosave_interval": 0})
json.dump(s, open(sys.argv[1], "w"), indent=1)
PY
    rm -f "$DIR/saves/spike.zip"
    "$BIN" --config "$DIR/config.ini" --mod-directory "$DIR/mods" --create "$DIR/saves/spike.zip" > "$DIR/create.log" 2>&1
    launch
    ;;
  *) echo "usage: $0 start|stop"; exit 2 ;;
esac
