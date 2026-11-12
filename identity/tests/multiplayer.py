#!/usr/bin/env python3
"""Isolated real server/two-client late-join regression. Requires Factorio 2.1.24.
Uses disposable profiles and only terminates processes it started.
"""
import argparse, hashlib, json, pathlib, shutil, socket, struct, subprocess, time, zipfile
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--factorio',type=pathlib.Path,required=True)
p.add_argument('--source',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[1]/'mod')
p.add_argument('--output',type=pathlib.Path,required=True)
p.add_argument('--extra-mod',type=pathlib.Path,action='append',default=[])
p.add_argument('--hold-seconds',type=int,default=0)
p.add_argument('--port',type=int,default=34530)
p.add_argument('--rcon-port',type=int,default=27530)
a=p.parse_args();root=a.output.resolve();src=a.source.resolve();exe=a.factorio.resolve()
if root.exists(): raise SystemExit('Output must be a new directory')
root.mkdir(parents=True);processes={};logs={};results=[]
source_hashes={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(src.iterdir()) if f.is_file()}
extra_hashes={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in a.extra_mod}
version=subprocess.check_output([str(exe),'--version'],text=True).strip()
def wait_for(fn,label,timeout=90):
    end=time.monotonic()+timeout
    while time.monotonic()<end:
        if fn(): return
        if any(v.poll() is not None for v in processes.values()): raise RuntimeError('Owned process exited during '+label)
        time.sleep(.25)
    raise TimeoutError(label)
def packet(i,t,b):
    d=struct.pack('<ii',i,t)+b.encode()+b'\0\0';return struct.pack('<i',len(d))+d
def read_exact(s,n):
    out=b''
    while len(out)<n:
        b=s.recv(n-len(out))
        if not b: raise EOFError('RCON closed')
        out+=b
    return out
def receive(s):
    n=struct.unpack('<i',read_exact(s,4))[0];d=read_exact(s,n)
    return struct.unpack('<ii',d[:8])+(d[8:-2].decode(),)
def rcon(command):
    with socket.create_connection(('127.0.0.1',a.rcon_port),timeout=10) as s:
        s.sendall(packet(1,3,'local-identity-test'))
        while True:
            i,t,b=receive(s)
            if t==2:
                if i==-1: raise RuntimeError('RCON auth failed')
                break
        s.sendall(packet(2,2,command))
        while True:
            i,t,b=receive(s)
            if i==2:
                if 'Error' in b or 'stack traceback' in b: raise RuntimeError(b)
                return b

def start(name,extra):
    profile=root/name;logs[name]=open(root/(name+'.log'),'a')
    cmd=[str(exe),'--disable-audio','--window-size','1280x800','--config',str(profile/'config.ini'),'--mod-directory',str(profile/'mods')]+extra
    processes[name]=subprocess.Popen(cmd,stdout=logs[name],stderr=subprocess.STDOUT)
    (root/(name+'.pid')).write_text(str(processes[name].pid))
def stop(name):
    proc=processes.pop(name,None)
    if proc and proc.poll() is None:
        proc.terminate()
        try: proc.wait(20)
        except subprocess.TimeoutExpired: proc.kill();proc.wait(10)
    if name in logs: logs.pop(name).close()
def server(save):
    start('server',['--start-server',str(save),'--server-settings',str(root/'settings.json'),'--server-adminlist',str(root/'admins.json'),'--port',str(a.port),'--bind','127.0.0.1','--rcon-bind',f'127.0.0.1:{a.rcon_port}','--rcon-password','local-identity-test'])
    def ready():
        try: return rcon('/sc rcon.print("ready")').strip()=='ready'
        except (OSError,EOFError): return False
    wait_for(ready,'server ready')
def client(name):
    start(name,['--mp-connect',f'127.0.0.1:{a.port}'])
    wait_for(lambda:rcon('/sc local p=game.get_player("'+name+'");rcon.print(p and p.connected or false)').strip()=='true','join '+name)
def dump(tag,names):
    # Diagnostics are intentionally excluded: only authoritative storage is compared.
    command='/sc __fabric-playground__ helpers.write_file("identity/'+tag+'.txt",serpent.block(storage,{sortkeys=true,comment=false,nocode=true}),false);rcon.print("dumped")'
    rcon(command)
    paths={n:root/n/'data/script-output/identity'/(tag+'.txt') for n in names}
    wait_for(lambda:all(f.exists() for f in paths.values()),'dump '+tag)
    hashes={n:hashlib.sha256(f.read_bytes()).hexdigest() for n,f in paths.items()}
    passed=len(hashes)==len(names) and len(set(hashes.values()))==1
    results.append({'step':tag,'pass':passed,'hashes':hashes})
    print(json.dumps(results[-1]),flush=True)
    if not passed: raise AssertionError('Peer storage differs: '+tag)
try:
    info=json.loads((src/'info.json').read_text());modname=info['name']+'_'+info['version']
    archive=root/(modname+'.zip')
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for f in sorted(src.iterdir()):
            if f.is_file(): z.write(f,modname+'/'+f.name)
    for name in ('server','identityA','identityB'):
        d=root/name;(d/'mods').mkdir(parents=True);(d/'data/saves').mkdir(parents=True)
        shutil.copy2(archive,d/'mods'/archive.name)
        for extra in a.extra_mod: shutil.copy2(extra,d/'mods'/extra.name)
        (d/'mods/mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':n in ('base',info['name'])} for n in ('base','space-age','quality','elevated-rails',info['name'])]}))
        if a.extra_mod:
            modlist=json.loads((d/'mods/mod-list.json').read_text())
            for extra in a.extra_mod:
                with zipfile.ZipFile(extra) as z:
                    modinfo=json.loads(z.read(next(n for n in z.namelist() if n.endswith('/info.json'))))
                modlist['mods'].append({'name':modinfo['name'],'enabled':True})
            (d/'mods/mod-list.json').write_text(json.dumps(modlist))
        (d/'config.ini').write_text('[path]\nread-data=__PATH__system-read-data__\nwrite-data='+str(d/'data')+'\n[other]\ncheck-updates=false\n[graphics]\nfull-screen=false\nwindow-size=800x600\n')
        (d/'data/player-data.json').write_text(json.dumps({'service-username':name,'service-token':''}))
    settings=json.loads((exe.parent.parent/'data/server-settings.example.json').read_text())
    settings.update(name='identity-regression',visibility={'public':False,'lan':False},require_user_verification=False,max_players=4,autosave_interval=0,auto_pause=False,allow_commands='true',username='',password='',token='')
    (root/'settings.json').write_text(json.dumps(settings));(root/'admins.json').write_text('["identityA","identityB"]')
    save=root/'initial.zip'
    with open(root/'create.log','w') as f: subprocess.run([str(exe),'--config',str(root/'server/config.ini'),'--mod-directory',str(root/'server/mods'),'--create',str(save)],stdout=f,stderr=subprocess.STDOUT,check=True,timeout=90)
    server(save);client('identityA')
    for suite,interface,method in [('core','fabric-campaign-tests','core'),('engine','fabric-campaign-tests','engine'),('domain','fabric-coverage-range','run')]:
        rcon('/sc local result=remote.call("'+interface+'","'+method+'");helpers.write_file("identity/'+suite+'.json",helpers.table_to_json(result),false);rcon.print("written")')
        result_path=root/'server/data/script-output/identity'/(suite+'.json')
        wait_for(lambda:result_path.exists(),'engine result '+suite)
        data=json.loads(result_path.read_text())
        failed=data.get('failures',sum(not c['pass'] for c in data.get('cases',[])))
        results.append({'step':suite,'pass':failed==0,'failures':failed,'checks':len(data.get('cases',data.get('scenarios',[])))})
        print(json.dumps(results[-1]),flush=True)
        if failed: raise AssertionError('Engine suite failed: '+suite)

    rcon('/sc local s=game.surfaces[1];s.create_entity{name="iron-chest",position={5,5},force="player",raise_built=true};remote.call("fabric-playground","commit",1)')
    dump('before-late-join',['server','identityA'])
    client('identityB');time.sleep(2);dump('late-join',['server','identityA','identityB'])
    stop('identityB');time.sleep(1);client('identityB');dump('reconnect',['server','identityA','identityB'])
    rcon('/server-save identity-reload')
    saved=root/'server/data/saves/identity-reload.zip'
    wait_for(lambda:saved.exists(),'saved ZIP')
    time.sleep(1)
    with zipfile.ZipFile(saved) as z: assert z.testzip() is None
    for name in list(processes): stop(name)
    server(saved);client('identityA');client('identityB');dump('save-reload',['server','identityA','identityB'])
    if a.hold_seconds:
        (root/'ready').write_text('Disposable clients ready for native input checks')
        print('READY for native input checks',flush=True)
        end=time.monotonic()+a.hold_seconds
        while time.monotonic()<end and not (root/'stop').exists(): time.sleep(.5)
finally:
    for name in list(processes): stop(name)
    (root/'results.json').write_text(json.dumps({'steps':results,'source_sha256':source_hashes,'extra_mod_sha256':extra_hashes,'engine_version':version,'source_unchanged':source_hashes=={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(src.iterdir()) if f.is_file()}},indent=2))
