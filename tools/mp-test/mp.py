#!/usr/bin/env python3
"""mp.py sc '<lua>' | dump TAG | cmp TAG"""
import subprocess,sys,os,hashlib,glob
R=os.path.expanduser('~/fabric-mp-test')
def rcon(cmd): return subprocess.run(['python3',R+'/tools/rcon.py',cmd],capture_output=True,text=True).stdout.strip()
def sc(lua,mod=False): return rcon('/sc '+('__fabric-playground__ ' if mod else '')+' '.join(l.strip() for l in lua.splitlines() if l.strip() and not l.strip().startswith('--')))
def dump(tag): return sc(open(R+'/tools/dump.lua').read().replace('TAG',repr(tag)),mod=True)
def cmp(tag):
    out=[]
    for kind in ('storage','elig'):
        hs={}
        for p in ('server','a','b'):
            f=f'{R}/{p}/data/script-output/mp/{tag}-{kind}.txt'
            if os.path.exists(f): hs[p]=hashlib.sha256(open(f,'rb').read()).hexdigest()[:12]
        out.append(f'{tag} {kind}: '+' '.join(f'{p}={h}' for p,h in hs.items())+('  SAME' if len(set(hs.values()))==1 else '  DIFFERENT'))
    return '\n'.join(out)
if __name__=='__main__':
    c=sys.argv[1]
    if c=='sc': print(sc(sys.argv[2], len(sys.argv)>3))
    elif c=='dump': print(dump(sys.argv[2]))
    elif c=='cmp': print(cmp(sys.argv[2]))
