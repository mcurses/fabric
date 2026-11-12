#!/usr/bin/env python3
"""Read-only source test runner; JSON stdout, exit0 pass/1 regression/2 harness error."""
import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('module_directory', type=pathlib.Path)
p.add_argument('--lua', default='lua')
a = p.parse_args()
root = a.module_directory.resolve()
files = sorted(root.glob('*.lua'))
runner = pathlib.Path(__file__).with_name('identity-regressions.lua')
try:
    if not files:
        raise ValueError('No Lua modules found')
    executable = shutil.which(a.lua)
    if not executable:
        raise ValueError('Lua executable not found: ' + a.lua)
    contents = {f.name: f.read_bytes() for f in files}
    result = subprocess.run([executable, str(runner), str(root)], capture_output=True, text=True, timeout=60)
    data = json.loads(result.stdout)
    data['provenance'] = {
        'lua_executable': executable,
        'source_concatenated_sha256': hashlib.sha256(b''.join(contents[f.name] for f in files)).hexdigest(),
        'files_sha256': {name: hashlib.sha256(value).hexdigest() for name, value in contents.items()},
        'suite_sha256': hashlib.sha256(runner.read_bytes()).hexdigest(),
        'loaded_engine_claim': False,
        'source_files_unchanged_during_run': all(f.read_bytes() == contents[f.name] for f in files),
    }
    if result.stderr:
        data['stderr'] = result.stderr
    print(json.dumps(data, indent=2, sort_keys=True))
    sys.exit(1 if data['failed'] else 0)
except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
    print(json.dumps({'schema_version': 1, 'fatal': str(exc), 'kind': 'harness-error'}))
    sys.exit(2)
