#!/bin/bash
# S5 regression suite: runs every piece identity scenario on a fresh spike server, saves and reloads the map, grades
# everything again, and fails if either prototype (P1_things, P2_tools) is silently wrong anywhere.
#   spikes/s5.sh            full run (fresh server, scenarios, reload, grades)
#   spikes/s5.sh --no-start run on the server that is already up, without the reload
set -euo pipefail
cd "$(dirname "$0")"
OUT="${S5_OUT:-$HOME/fabric-spike/s5}"
mkdir -p "$OUT"
call() { ./rcon.py - <<< "rcon.print(serpent.line(remote.call('fabric-spike-s5', $1), {comment=false}))"; }
evals() { for n in $names; do echo "== $n"; call "'eval', '$n'"; done; }

[[ "${1:-}" == "--no-start" ]] || ./server.sh start > /dev/null
names=$(./rcon.py - <<< "for _, n in ipairs(remote.call('fabric-spike-s5','names')) do rcon.print(n) end")
for n in $names; do
  call "'setup', '$n'" > /dev/null
  while [[ "$(call "'step', '$n'")" == '"more"' ]]; do sleep 0.3; done
  sleep 0.5
done
evals > "$OUT/run.txt"
echo "== leak" >> "$OUT/run.txt"; call "'leak'" >> "$OUT/run.txt"
if [[ "${1:-}" != "--no-start" ]]; then
  ./server.sh resume > /dev/null
  evals > "$OUT/reload.txt"
fi

python3 - "$OUT" <<'PY'
import os, re, sys
out = sys.argv[1]
def load(name):
    path = os.path.join(out, name)
    if not os.path.exists(path): return None
    res, cur = {}, None
    for line in open(path):
        line = line.rstrip("\n")
        if line.startswith("== "): cur = line[3:]; continue
        if cur and line.startswith("{") and "scenario" in line:
            row = {}
            for k, v in re.findall(r'(\w+) = "([^"]*)"', line): row[k] = v
            row["control"] = "control = true" in line
            res[cur] = row
    return res
run, reload = load("run.txt"), load("reload.txt")
cols = ["P1_things", "P2_tools", "guess", "carrier"]
print(f"{'scenario':32} " + " ".join(f"{c:10}" for c in cols))
fail = []
for sc, row in run.items():
    cells = [row.get(c, "-").split(":")[0] for c in cols]
    tag = " (control: no repair)" if row["control"] else ""
    print(f"{sc:32} " + " ".join(f"{c:10}" for c in cells) + tag)
    for c in ("P1_things", "P2_tools"):
        if not row["control"] and row.get(c, "").startswith("WRONG"):
            fail.append(f"{sc} {c}: {row[c]}")
if reload is not None:
    same = all(reload.get(sc, {}).get(c) == run[sc].get(c) for sc in run for c in cols)
    print("after save and reload:", "identical" if same else "DIFFERENT")
    if not same: fail.append("grades changed after reload")
for f in fail: print("FAIL", f)
sys.exit(1 if fail else 0)
PY
