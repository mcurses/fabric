#!/usr/bin/env python3
"""Prepare an isolated profile with the prototypes used by the real source book."""
import json,os,shutil,sys,zipfile
from pathlib import Path
profile=Path(sys.argv[1]); mods=profile/'mods';mods.mkdir(parents=True,exist_ok=True)
required=['0-things','cybersyn2','cybersyn','flib','GhostScanner4IgnoreAssigned']
roots=[mods]
if os.environ.get('FABRIC_SOURCE_MODS'): roots.append(Path(os.environ['FABRIC_SOURCE_MODS']))
roots.extend([Path.home()/'Library/Application Support/factorio/mods',Path.home()/'factorio-bv-test/mods'])
missing=[]
for name in required:
 candidates=[]
 for root in roots:
  for p in root.glob(name+'_*.zip'):
   try:
    with zipfile.ZipFile(p) as z:
     info=json.loads(z.read(next(n for n in z.namelist() if n.endswith('/info.json'))))
     if info['name']==name: candidates.append((tuple(map(int,info['version'].split('.'))),p))
   except (ValueError,KeyError,StopIteration,zipfile.BadZipFile): continue
 if not candidates: missing.append(name);continue
 _,source=max(candidates,key=lambda x:x[0]);target=mods/source.name
 if source.resolve()!=target.resolve():shutil.copy2(source,target)
if missing:sys.exit('Missing source-book mods: '+', '.join(missing)+'. Set FABRIC_SOURCE_MODS to your game mods folder.')
active=['base','space-age','quality','elevated-rails','recycler','fabric-ui-playground']+required
(mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':True} for n in active]},indent=2))
