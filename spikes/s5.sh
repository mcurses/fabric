#!/bin/bash
# Runs every S5 identity scenario on the running spike server and prints the graded results.
set -euo pipefail
cd "$(dirname "$0")"
call() { ./rcon.py - <<< "rcon.print(serpent.line(remote.call('fabric-spike-s5', $1), {comment=false}))"; }
names=$(./rcon.py - <<< "for _, n in ipairs(remote.call('fabric-spike-s5','names')) do rcon.print(n) end")
for n in $names; do
  echo "== $n"
  call "'setup', '$n'"
  while [[ "$(call "'step', '$n'")" == '"more"' ]]; do sleep 0.3; done
  sleep 0.5
  call "'eval', '$n'"
done
echo "== leak"
call "'leak'"
