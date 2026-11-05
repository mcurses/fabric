set -u; R=~/fabric-mp-test; F=/Applications/factorio.app/Contents/MacOS/factorio; cd $R/tools
srv(){ nohup $F --config $R/server/config.ini --mod-directory $R/server/mods --start-server $1 --server-settings $R/server-settings.json --server-adminlist $R/server-adminlist.json --port 34420 --rcon-port 27420 --rcon-password mptest > $R/server.log 2>&1 & echo $! > $R/server.pid; until grep -q "Starting RCON" $R/server.log; do sleep 1; done; }
cli(){ nohup $F --config $R/$1/config.ini --mod-directory $R/$1/mods --mp-connect 127.0.0.1:34420 > $R/$1.log 2>&1 & echo $! > $R/$1.pid; }
joined(){ until [ "$(grep -c "\[JOIN\] $1" $R/server.log)" -ge "$2" ]; do sleep 1; done; sleep 4; }
kill $(cat $R/b.pid); sleep 5
python3 mp.py dump s1
n=$(grep -c "\[JOIN\] fabricB" $R/server.log); cli b; joined fabricB $((n+1)); python3 mp.py dump s2
python3 rcon.py '/server-save mp1-reload2'; sleep 3
kill $(cat $R/server.pid); sleep 3; kill $(cat $R/a.pid) $(cat $R/b.pid); sleep 2
srv $R/server/data/saves/mp1-reload2.zip; cli a; joined fabricA 1; cli b; joined fabricB 1
python3 mp.py dump s3; sleep 2
for t in s1 s2 s3; do python3 mp.py cmp $t; done
grep -il desync $R/*/data/factorio-current.log $R/server.log || echo "no engine desync logged"
