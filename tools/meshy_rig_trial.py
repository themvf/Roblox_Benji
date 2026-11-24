"""Resume one Meshy rigging trial and download its rig plus basic movement clips."""
import argparse
import json
import time
import urllib.request
from pathlib import Path
from kit_look import meshy_call, meshy_key

p = argparse.ArgumentParser()
p.add_argument('folder', type=Path)
p.add_argument('--confirm', action='store_true')
a = p.parse_args()
folder = a.folder.resolve()
out = folder / 'meshy-rig'
out.mkdir(exist_ok=True)
record = out / 'task.json'
key = meshy_key()
if record.exists():
    task = json.loads(record.read_text())
else:
    source = json.loads((folder / 'meshy/task.json').read_text())
    settings = {'input_task_id': source['id'], 'height_meters': 1.8,
                'animation_type': 'biped', 'skeleton_template': 'meshyrig', 'include_fingers': False}
    print('Rigging trial; balance:', meshy_call(key, '/balance'), flush=True)
    if not a.confirm:
        raise SystemExit('Dry run. --confirm submits one rigging task.')
    task = {'id': meshy_call(key, '/rigging', settings)['result'], 'settings': settings}
    record.write_text(json.dumps(task, indent=2))
    print('Submitted:', task['id'], flush=True)
for _ in range(180):
    state = meshy_call(key, '/rigging/' + task['id'])
    task.update(status=state['status'], credits=state.get('consumed_credits'), error=state.get('task_error'))
    record.write_text(json.dumps(task, indent=2))
    print(state['status'], state.get('progress'), flush=True)
    if state['status'] == 'SUCCEEDED':
        result = state['result']
        urls = {k: v for k, v in result.items() if isinstance(v, str)}
        urls.update(result.get('basic_animations') or {})
        files = []
        for name, url in urls.items():
            if not url:
                continue
            path = out / name.removesuffix('_url').replace('rigged_character', 'RangerRig')
            ext = '.fbx' if 'fbx' in name else '.glb'
            path = path.with_suffix(ext)
            if not path.exists():
                urllib.request.urlretrieve(url, path)
            files.append(path.name)
        task['files'] = files
        record.write_text(json.dumps(task, indent=2))
        print('Downloaded:', files, 'credits:', task['credits'], flush=True)
        break
    if state['status'] in ('FAILED', 'CANCELED'):
        raise SystemExit(str(state.get('task_error')))
    time.sleep(10)
else:
    raise SystemExit('Still running; rerun to resume the same task.')
