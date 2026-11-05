#!/bin/bash
# Build ~/fabric-mp-test: one headless server and two client profiles (fabricA, fabricB) on one Mac,
# all loading the same mod zip. Usage: setup.sh <mod source dir>   (needs Factorio 2.1.24 in /Applications)
set -e; SRC=$1; R=~/fabric-mp-test; F=/Applications/factorio.app/Contents/MacOS/factorio
NAME=$(python3 -c "import json;print(json.load(open('$SRC/info.json'))['name'])"); VER=$(python3 -c "import json;print(json.load(open('$SRC/info.json'))['version'])")
mkdir -p $R/{server,a,b}/{mods,data} $R/saves $R/server/data/saves $R/tools; cp "$(dirname "$0")"/{rcon.py,mp.py,dump.lua,run3.sh} $R/tools/
rm -rf $R/build; mkdir -p $R/build/${NAME}_$VER; cp $SRC/*.lua $SRC/info.json $R/build/${NAME}_$VER/
(cd $R/build && zip -qr -X ${NAME}_$VER.zip ${NAME}_$VER)
for p in server a b; do
  cp $R/build/${NAME}_$VER.zip $R/$p/mods/
  printf '{"mods":[{"name":"base","enabled":true},{"name":"space-age","enabled":false},{"name":"quality","enabled":false},{"name":"elevated-rails","enabled":false},{"name":"%s","enabled":true}]}\n' $NAME > $R/$p/mods/mod-list.json
  printf '[path]\nread-data=__PATH__system-read-data__\nwrite-data=%s\n' "$R/$p/data" > $R/$p/config.ini
done
for p in a b; do n=fabric$(echo $p | tr ab AB); echo "{\"service-username\":\"$n\",\"service-token\":\"\"}" > $R/$p/data/player-data.json; done
python3 - <<'P'
import json,os
ex=json.load(open('/Applications/factorio.app/Contents/data/server-settings.example.json'))
ex.update({"name":"fabric-mp-test","description":"local two-client test","visibility":{"public":False,"lan":False},"require_user_verification":False,"max_players":4,"autosave_interval":0,"auto_pause":False,"allow_commands":"true","username":"","password":"","token":""})
json.dump(ex,open(os.path.expanduser('~/fabric-mp-test/server-settings.json'),'w'),indent=1)
P
printf '["fabricA","fabricB"]' > $R/server-adminlist.json
$F --config $R/server/config.ini --mod-directory $R/server/mods --create $R/saves/mp1.zip > $R/create.log 2>&1
shasum -a 256 $R/*/mods/${NAME}_$VER.zip
