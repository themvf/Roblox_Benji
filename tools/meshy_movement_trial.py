"""Apply selected Meshy movement clips to an existing rig; resume saved tasks."""
import json,time,urllib.request,argparse
from pathlib import Path
from kit_look import meshy_key,meshy_call
p=argparse.ArgumentParser();p.add_argument('folder',type=Path);a=p.parse_args()
base=a.folder.resolve();out=base/'movements';out.mkdir(exist_ok=True)
rig=json.loads((base/'task.json').read_text())['id'];key=meshy_key()
jobs=[]
for name,aid in [('slide',517),('jump',466),('crouch',616)]:
    record=out/(name+'-task.json')
    if record.exists(): task=json.loads(record.read_text())
    else:
        settings={'rig_task_id':rig,'action_id':aid}
        task={'id':meshy_call(key,'/animations',settings)['result'],'settings':settings}
        record.write_text(json.dumps(task,indent=2))
    jobs.append((name,record,task))
for name,record,task in jobs:
    for _ in range(180):
        state=meshy_call(key,'/animations/'+task['id']);print(name,state['status'],state.get('progress'),flush=True)
        task.update(status=state['status'],credits=state.get('consumed_credits'),error=state.get('task_error'))
        record.write_text(json.dumps(task,indent=2))
        if state['status']=='SUCCEEDED':
            task['files']=[]
            for ext in ['glb','fbx']:
                url=state['result'].get('animation_'+ext+'_url')
                if url:
                    target=out/(name+'.'+ext)
                    if not target.exists():urllib.request.urlretrieve(url,target)
                    task['files'].append(target.name)
            record.write_text(json.dumps(task,indent=2));break
        if state['status'] in ['FAILED','CANCELED']:raise SystemExit(str(state.get('task_error')))
        time.sleep(10)
    else:raise SystemExit('Still running; rerun to resume')
