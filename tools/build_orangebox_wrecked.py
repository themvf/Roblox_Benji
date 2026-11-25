"""Build, appraise, render and validate the ransacked orange cargo box.

python tools/build_orangebox_wrecked.py
python tools/build_orangebox_wrecked.py --check-only
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
PKG=ROOT/'assets/models/orangebox'
VIEWS={'front-quarter':'9,6,10','side':'0,5,13',
       'end':'13,5,0','rear':'-9,6,-10'}
ORIGINAL='7c047dd46eba8482bf2799af0f0122d9eedcfc03b93f4e71f556b30e31bf5ce6'
LEGACY='a11bff9ffce1656e6674916b9f769265450ec41b703c26765a885bd14ec9def0'
DECISION=(
    'Ransacked small sci-fi cargo box, clean hard-surface rebuild from the '
    'user-selected TRELLIS source and matching Midjourney reference. White '
    'chipped panels, charcoal protective frame, orange latches, torn side '
    'hatch, pried lid, forced end door and scattered orange cargo cases. '
    'Second detail pass adds lid ribs, service slats, panel seams, fasteners, '
    'vents, hinge hardware, latch controls, base grilles, case clasps and '
    'loose cartridges, following the user request for more detail. '
    'A later partial-blast pass breaks the front roof rail and upper wall, '
    'with asymmetric soot, bent hot metal, exposed ribs, a sheared hinge '
    'and attached floor fragments. '
    'Realism pass transfers fine surface variation from the original TRELLIS '
    'color atlas, adds edge wear, exposed metallic chips, roughness variation '
    'and a subtle tangent-space normal map. '
    'One mesh with color, metallic-roughness and normal atlas maps. The earlier '
    '9,000-triangle optimized export is preserved as a trial. Provisional '
    'size is 3.8 studs high; role is decoration pending user approval.'
)

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def validate():
    path=PKG/'exports/OrangeBoxRansacked.glb'
    doc,blob=gltf_post.read_glb(path)
    if len(doc.get('meshes',[]))!=1 or len(doc.get('materials',[]))!=1:
        raise RuntimeError('Expected one mesh and one material')
    mesh=doc['meshes'][0]
    if len(mesh['primitives'])!=1:raise RuntimeError('Expected one primitive')
    prim=mesh['primitives'][0]
    if prim.get('mode',4)!=4 or 'TEXCOORD_0' not in prim['attributes']:
        raise RuntimeError('Expected triangle primitive and UVs')
    count=doc['accessors'][prim['indices']]['count']//3
    if not 0<count<10000:raise RuntimeError('Roblox triangle cap exceeded')
    pos=doc['accessors'][prim['attributes']['POSITION']]
    lo,hi=pos['min'],pos['max']
    if abs(lo[1])>.005 or abs(hi[1]-3.8)>.005:
        raise RuntimeError('Expected bottom pivot and 3.8-stud height')
    if abs(lo[0]+hi[0])>.005 or abs(lo[2]+hi[2])>.005:
        raise RuntimeError('Expected centered horizontal bounds')
    if not (6.5<hi[0]-lo[0]<7.1 and 4.8<hi[2]-lo[2]<5.6):
        raise RuntimeError('Unexpected open-door footprint')
    if any(key in node for node in doc['nodes']
           for key in ('matrix','translation','rotation','scale')):
        raise RuntimeError('Unexpected object transform')
    if gltf_post.foreign_textures(doc):
        raise RuntimeError('Unsupported embedded texture')
    textures=gltf_post.texture_info(doc,blob)
    if len(textures)!=3 or any(item!=('image/png',(1024,1024)) for item in textures):
        raise RuntimeError('Expected three embedded 1024 PNGs')
    if 'normalTexture' not in doc['materials'][0]:
        raise RuntimeError('Normal map is not connected')
    if sha(PKG/'source/trellis-original.glb')!=ORIGINAL:
        raise RuntimeError('TRELLIS original changed')
    if sha(PKG/'trials/OrangeBox_legacy_9000.glb')!=LEGACY:
        raise RuntimeError('Legacy export changed')
    if sha(PKG/'trials/OrangeBoxRansacked_v1.glb')!=\
            'a161663b9c182fbd8a7bf4e22bc1895f4d68a582aac44a29e2c8837e03402826':
        raise RuntimeError('First ransacked version changed')
    if sha(PKG/'trials/OrangeBoxRansacked_v2_detail.glb')!=\
            'b8fb4b51ddfa97750dd84fcf3223bfdb9c112ecfb74d40ed6738997a6a1fdd7b':
        raise RuntimeError('Detailed pre-blast version changed')
    if sha(PKG/'trials/OrangeBoxRansacked_v3_blast.glb')!=\
            '13322f33c34d35316e48f9cd45335552b5560c7568093ca094be4d8bb12def1e':
        raise RuntimeError('Pre-realism blast version changed')
    appraisal=json.loads((PKG/'appraisal.json').read_text(encoding='utf-8'))
    if appraisal.get('sourceSha256')!=sha(path) or appraisal.get('decision')!=DECISION:
        raise RuntimeError('Final export appraisal is stale')
    required=['source/design-reference.png','source/trellis-original.glb',
              'source/trellis-basecolor.png',
              'source/trellis-appraisal.json','source/OrangeBox_Ransacked.blend',
              'exports/OrangeBoxRansacked.glb','textures/OrangeBox_Color.png',
              'textures/OrangeBox_Roughness.png','textures/OrangeBox_Metalness.png',
              'textures/OrangeBox_Normal.png',
              'trials/OrangeBox_legacy_9000.glb','review/legacy-quarter.png',
              'trials/OrangeBoxRansacked_v1.glb',
              'trials/OrangeBoxRansacked_v1-front-quarter.png',
              'trials/OrangeBoxRansacked_v2_detail.glb',
              'trials/OrangeBoxRansacked_v2_detail-front-quarter.png',
              'trials/OrangeBoxRansacked_v3_blast.glb',
              'trials/OrangeBoxRansacked_v3_blast-front-quarter.png',
              'SetupOrangeBox.luau','appraisal.json']
    required += [f'review/ransacked-{view}.png' for view in VIEWS]
    return {name:sha(PKG/name) for name in required},{
        'triangles':count,'meshes':1,'materials':1,'boundsMin':lo,
        'boundsMax':hi,'embeddedTextures':textures,'exportBytes':path.stat().st_size}

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
                if candidate.exists():blender=candidate
            if not blender:raise RuntimeError('Blender 4.3 missing')
            backup=ROOT/'.mapbuild/orangebox-wrecked'/stamp
            backup.mkdir(parents=True)
            for name in ('source/OrangeBox_Ransacked.blend',
                         'exports/OrangeBoxRansacked.glb','appraisal.json')+tuple(
                             f'review/ransacked-{view}.png' for view in VIEWS):
                src=PKG/name
                if src.exists():
                    dst=backup/name;dst.parent.mkdir(parents=True,exist_ok=True)
                    shutil.copy2(src,dst)
            report['backup']=str(backup.relative_to(ROOT))
            def run(label,script,*arguments):
                command=[str(blender),'--factory-startup','-b','--python-exit-code',
                         '1','--python',script]
                if arguments:command += ['--',*arguments]
                print(label,flush=True)
                with (backup/(label+'.log')).open('w',encoding='utf-8') as log:
                    subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,
                                   check=True,timeout=600)
            run('author','tools/blender/build_orangebox_wrecked.py')
            run('appraise','tools/blender/appraise_asset.py','--source',
                str(PKG/'exports/OrangeBoxRansacked.glb'),
                '--record',str(PKG/'appraisal.json'))
            appraisal=json.loads((PKG/'appraisal.json').read_text(encoding='utf-8'))
            appraisal['decision']=DECISION
            (PKG/'appraisal.json').write_text(json.dumps(appraisal,indent=2)+'\n',encoding='utf-8')
            for view,eye in VIEWS.items():
                run('render-'+view,'tools/blender/preview_scene.py','--glb',
                    'assets/models/orangebox/exports/OrangeBoxRansacked.glb',
                    '--materials','original','--no-arena','--eye='+eye,
                    '--look','0,1.9,0','--lens','42','--resolution','960,640',
                    '--samples','24','--ground','120','--ground-y=-0.05',
                    '--out',str(PKG/f'review/ransacked-{view}.png'))
        report['filesSha256'],report['measured']=validate()
        report['status']='passed'
        report['limitations']=[
            'Local GLB checks and Blender renders do not establish user visual approval.',
            'New export has not been imported into Studio or placed in a map.',
            '3.8-stud height and decoration role are provisional.',
            'Check-only hashes previews but does not regenerate them.',
            'Repository-wide Lune gate could not start in this sandbox (cwd access denied).'
        ]
    except Exception as exc:
        report['status']='failed';report['error']=str(exc)
        raise
    finally:
        output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('PASS: ransacked orange box local package; visual approval and Studio import pending')

if __name__=='__main__':main()
