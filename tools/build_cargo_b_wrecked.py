"""Rebuild, appraise, render and validate the ransacked cargo-b candidate.

python tools/build_cargo_b_wrecked.py
python tools/build_cargo_b_wrecked.py --check-only
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import gltf_post

ROOT=Path(__file__).resolve().parents[1]
PKG=ROOT/'assets/models/cargo-b'
VIEWS={'front-quarter':'14,9,13','side':'0,5,17',
       'end':'18,5,0','rear':'-16,6,-12'}
DECISION=(
    'Clean, weathered and ransacked rebuild of the selected white cargo unit. '
    'The prior intact 7,498-triangle voxel export and its failed Studio uploads '
    'are preserved as trial history. This candidate follows the Midjourney '
    'proportions and white panel/corner-cap design, with a broken side opening, '
    'opened end doors, roof tears, exposed cases, fallen rack and loose metal. '
    'Decoration role and six-stud height are provisional until user approval.'
)
ORIGINAL='c768671f5c5e8d87837b0fed4ec02abb87b3ef64810c5d0096b090fa56d1ad54'

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def validate():
    path=PKG/'exports/CargoUnit.glb'
    doc,blob=gltf_post.read_glb(path)
    if len(doc.get('meshes',[]))!=1 or len(doc.get('materials',[]))!=1:
        raise RuntimeError('Expected one mesh and one material')
    mesh=doc['meshes'][0]
    if len(mesh['primitives'])!=1: raise RuntimeError('Expected one primitive')
    prim=mesh['primitives'][0]
    if prim.get('mode',4)!=4 or 'TEXCOORD_0' not in prim['attributes']:
        raise RuntimeError('Expected triangles and UVs')
    tris=doc['accessors'][prim['indices']]['count']//3
    if not 0<tris<10000: raise RuntimeError('Triangle limit exceeded')
    pos=doc['accessors'][prim['attributes']['POSITION']]
    lo,hi=pos['min'],pos['max']
    if abs(lo[1])>.005 or abs(hi[1]-6)>.005:
        raise RuntimeError('Expected six-stud height and bottom pivot')
    if abs(lo[0]+hi[0])>.005 or abs(lo[2]+hi[2])>.005:
        raise RuntimeError('Expected centered horizontal bounds')
    if not (9<hi[0]-lo[0]<10 and 6<hi[2]-lo[2]<7):
        raise RuntimeError('Unexpected footprint')
    if any(key in node for node in doc['nodes']
           for key in ('matrix','translation','rotation','scale')):
        raise RuntimeError('Unexpected GLB object transform')
    if gltf_post.foreign_textures(doc):
        raise RuntimeError('Unsupported texture format')
    textures=gltf_post.texture_info(doc,blob)
    if len(textures)!=2 or any(item!=('image/png',(1024,1024)) for item in textures):
        raise RuntimeError('Expected two embedded 1024 PNG textures')
    if sha(PKG/'source/trellis-original.glb')!=ORIGINAL:
        raise RuntimeError('Original TRELLIS intake changed')
    if sha(PKG/'trials/CargoUnit_intact_20260928.glb')!=\
            '9bcf63d83e5d7e9a9ca731085780c0596d512dfe4dcbd3142e425e13c5c691b5':
        raise RuntimeError('Preserved intact export changed')
    appraisal=json.loads((PKG/'appraisal.json').read_text(encoding='utf-8'))
    if appraisal.get('sourceSha256')!=sha(path) or appraisal.get('decision')!=DECISION:
        raise RuntimeError('Export appraisal is stale')
    required=['source/design-reference.png','source/trellis-original.glb',
              'source/CargoB_Wreck.blend','exports/CargoUnit.glb',
              'textures/CargoB_Wreck_Color.png','textures/CargoB_Wreck_Roughness.png',
              'textures/CargoB_Wreck_Metalness.png','appraisal.json',
              'SetupCargoUnit.luau','trials/CargoUnit_intact_20260928.glb',
              'trials/intact-front-quarter.png']
    required += [f'review/wreck-{view}.png' for view in VIEWS]
    return {name:sha(PKG/name) for name in required},{
        'triangles':tris,'meshes':1,'materials':1,'boundsMin':lo,'boundsMax':hi,
        'embeddedTextures':textures,'exportBytes':path.stat().st_size}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--check-only',action='store_true')
    p.add_argument('--blender',type=Path)
    args=p.parse_args()
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    report={'checkedAtUtc':stamp,'mode':'check' if args.check_only else 'rebuild',
            'status':'running','visualApproval':'pending','studioImport':'unverified'}
    output=PKG/'validation.json'
    try:
        if not args.check_only:
            blender=args.blender or shutil.which('blender')
            if not blender and os.name=='nt':
                candidate=Path(os.environ.get('ProgramFiles','C:/Program Files'))/\
                    'Blender Foundation/Blender 4.3/blender.exe'
                if candidate.exists(): blender=candidate
            if not blender: raise RuntimeError('Blender 4.3 missing')
            backup=ROOT/'.mapbuild/cargo-b-wrecked'/stamp
            backup.mkdir(parents=True)
            for name in ('source/CargoB_Wreck.blend','exports/CargoUnit.glb',
                         'appraisal.json','views.png')+tuple(
                             f'review/wreck-{view}.png' for view in VIEWS):
                src=PKG/name
                if src.exists():
                    dst=backup/name; dst.parent.mkdir(parents=True,exist_ok=True)
                    shutil.copy2(src,dst)
            report['backup']=str(backup.relative_to(ROOT))
            def run(label,script,*arguments):
                command=[str(blender),'--factory-startup','-b','--python-exit-code','1',
                         '--python',script]
                if arguments: command += ['--',*arguments]
                print(label,flush=True)
                with (backup/(label+'.log')).open('w',encoding='utf-8') as log:
                    subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,
                                   check=True,timeout=600)
            run('author','tools/blender/build_cargo_b_wrecked.py')
            run('appraise','tools/blender/appraise_asset.py','--source',
                str(PKG/'exports/CargoUnit.glb'),'--record',str(PKG/'appraisal.json'))
            appraisal=json.loads((PKG/'appraisal.json').read_text(encoding='utf-8'))
            appraisal['decision']=DECISION
            (PKG/'appraisal.json').write_text(json.dumps(appraisal,indent=2)+'\n',encoding='utf-8')
            for view,eye in VIEWS.items():
                run('render-'+view,'tools/blender/preview_scene.py','--glb',
                    'assets/models/cargo-b/exports/CargoUnit.glb','--materials','original',
                    '--no-arena','--eye='+eye,'--look','0,2.8,0','--lens','40',
                    '--resolution','960,640','--samples','24','--ground','200',
                    '--ground-y=-0.05','--out',str(PKG/f'review/wreck-{view}.png'))
        report['filesSha256'],report['measured']=validate()
        report['status']='passed'
        report['limitations']=[
            'File checks and renders do not establish user visual approval.',
            'New export has not been imported into Studio or placed in a map.',
            'Six-stud height and decoration role remain provisional.',
            'Check-only hashes existing previews; it does not regenerate them.',
            'Repository-wide Lune gate could not start in this sandbox (cwd access denied).'
        ]
    except Exception as exc:
        report['status']='failed'; report['error']=str(exc)
        raise
    finally:
        output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('PASS: ransacked cargo-b local package; visual approval and Studio import pending')

if __name__=='__main__': main()
