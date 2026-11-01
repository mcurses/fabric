#!/bin/bash
set -euo pipefail
SOURCE=$(cd "$(dirname "$0")" && pwd)
INPUT=${1:?Usage: prepare-handover.sh source-save.zip output-directory}
OUT=${2:?Provide output-directory}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
QA=$(mktemp -d "${TMPDIR:-/tmp}/fabric-handover.XXXXXX")
trap 'rm -rf "$QA"' EXIT
BIN="${FACTORIO_BIN:-$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio}"
mkdir -p "$QA/mods" "$QA/saves"
ln -s "$SOURCE/mod" "$QA/mods/fabric-ui-playground"
cp -R "$SOURCE/tests/test-driver" "$QA/mods/fabric-ui-test-driver"
printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$QA" > "$QA/config.ini"
python3 "$SOURCE/prepare-mods.py" "$QA"
python3 - "$QA/mods/mod-list.json" <<'PY'
import json,sys
p=sys.argv[1];j=json.load(open(p));j['mods'].append({'name':'fabric-ui-test-driver','enabled':True});open(p,'w').write(json.dumps(j))
PY
python3 - "$QA" "$BIN" "$INPUT" "$OUT" <<'PYRUN'
import json,sys,subprocess,time,socket,signal
from pathlib import Path
qa,binary,source,out=sys.argv[1:];qa=Path(qa);out=Path(out)
p=qa/'mods/fabric-ui-test-driver/control.lua'
p.write_text(p.read_text().replace('local mode=script.test_arg',"local mode=script.test_arg or 'handover'"))
settings=qa/'server-settings.json'
settings_data=json.loads((Path(binary).parent.parent/'data/server-settings.example.json').read_text())
settings_data.update({'name':'Fabric isolated save preparation','description':'Local disposable save preparation','visibility':{'public':False,'lan':False},'require_user_verification':False,'auto_pause':False,'autosave_interval':0})
settings.write_text(json.dumps(settings_data))
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:
 sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
with open(out/'preparation.log','w') as log:
 proc=subprocess.Popen([binary,'--config',str(qa/'config.ini'),'--mod-directory',str(qa/'mods'),'--start-server',source,'--server-settings',str(settings),'--bind','127.0.0.1','--port',str(port)],stdout=log,stderr=subprocess.STDOUT)
 try:
  deadline=time.time()+150
  while time.time()<deadline:
   if proc.poll() is not None:raise RuntimeError('Preparation server exited; see preparation.log')
   if (qa/'script-output/handover-ready.txt').exists() and (qa/'saves/fabric-handover.zip').exists():break
   time.sleep(1)
  else:raise RuntimeError('Preparation timed out; see preparation.log')
 finally:
  if proc.poll() is None:
   proc.send_signal(signal.SIGINT)
   try:proc.wait(timeout=15)
   except subprocess.TimeoutExpired:proc.kill();proc.wait()
import shutil
shutil.copy2(qa/'saves/fabric-handover.zip',out/'starter.zip')
PYRUN
cp "$QA/script-output/handover-catalog.json" "$OUT/catalog.json"
"$BIN" --config "$QA/config.ini" --mod-directory "$QA/mods" --test-save "$OUT/starter.zip" --test-arg handover-check --test-ticks 1200 > "$OUT/reload-check.log" 2>&1
echo "Prepared and verified: $OUT/starter.zip"
