"""Rebuild, render and validate the rack; never upload or alter Roblox Studio.

python tools/build_server_rack.py
python tools/build_server_rack.py --check-only
Use --blender PATH when Blender is not on PATH or in the usual Windows folder.
Generated outputs are backed up under .mapbuild before a rebuild.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import gltf_post

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / 'assets/models/server-rack'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate():
    export = PACKAGE / 'exports/ServerRack.glb'
    doc, blob = gltf_post.read_glb(export)
    if gltf_post.report(export, 'final') > 5000:
        raise RuntimeError('Rack exceeds its 5000-triangle project budget')
    if len(doc['meshes']) != 1 or len(doc['materials']) != 1:
        raise RuntimeError('Expected one mesh and one material')
    prims = doc['meshes'][0]['primitives']
    if len(prims) != 1 or prims[0].get('mode', 4) != 4:
        raise RuntimeError('Expected one triangle primitive')
    for node in doc['nodes']:
        if any(key in node for key in ('matrix', 'translation', 'rotation', 'scale')):
            raise RuntimeError('Unexpected object transform; recheck scale and pivot')
    pos = doc['accessors'][prims[0]['attributes']['POSITION']]
    if abs(pos['min'][1]) > 1e-5 or abs(pos['max'][1]-8) > 1e-5:
        raise RuntimeError('Expected bottom pivot and eight-stud height')
    if gltf_post.foreign_textures(doc):
        raise RuntimeError('Unsupported embedded texture format')
    for texture in doc.get('images', []):
        if texture.get('mimeType') != 'image/png':
            raise RuntimeError('Expected embedded PNG textures')
    textures = gltf_post.texture_info(doc, blob)
    if len(textures) != 2 or any(size != (1024, 1024) for _, size in textures):
        raise RuntimeError('Expected two embedded 1024-pixel texture maps')
    appraisal = json.loads((PACKAGE / 'appraisal.json').read_text())
    if not appraisal.get('decision'):
        raise RuntimeError('Missing intake decision')
    if appraisal['sourceSha256'] != digest(PACKAGE / 'source/ServerRack_Authored.glb'):
        raise RuntimeError('Appraisal is stale: rebuild the package')
    required = ['exports/ServerRack.glb', 'source/ServerRack.blend',
                'source/ServerRack_Authored.glb', 'source/design-reference.png',
                'review/prototype-front.png', 'review/prototype-rear.png',
                'textures/Rack_Color.png', 'textures/Rack_Roughness.png',
                'textures/Rack_Metalness.png', 'SetupDecoration.luau', 'appraisal.json']
    return {name: digest(PACKAGE/name) for name in required}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-only', action='store_true')
    parser.add_argument('--blender', type=Path)
    args = parser.parse_args()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    report = {'checkedAtUtc': stamp, 'mode': 'check' if args.check_only else 'rebuild',
              'status': 'running', 'studioVerified': False}
    report_path = PACKAGE/'validation.json'
    report_path.write_text(json.dumps(report, indent=2)+'\n')
    try:
        if not args.check_only:
            blender = args.blender or shutil.which('blender')
            if not blender and os.name == 'nt':
                candidate = Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Blender Foundation/Blender 4.3/blender.exe'
                if candidate.exists():
                    blender = candidate
            if not blender:
                raise RuntimeError('Blender missing. Supply --blender PATH. Tested with Blender 4.3.2.')
            backup = ROOT/'.mapbuild/server-rack'/stamp
            backup.mkdir(parents=True)
            for name in ('source', 'exports', 'textures', 'review'):
                if (PACKAGE/name).exists():
                    shutil.copytree(PACKAGE/name, backup/name)
            shutil.copy2(PACKAGE/'appraisal.json', backup/'appraisal.json')
            report['backup'] = str(backup.relative_to(ROOT))

            def run(label, script, *arguments):
                command = [str(blender), '--factory-startup', '-b', '--python-exit-code', '1',
                           '--python', script]
                if arguments:
                    command += ['--', *arguments]
                print(label, flush=True)
                with (backup/(label+'.log')).open('w', encoding='utf-8') as log:
                    subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                   check=True, timeout=600)

            run('author', 'tools/blender/build_server_rack.py')
            run('export', 'tools/blender/scene_kit.py', '--asset', 'server-rack')
            run('appraise', 'tools/blender/appraise_asset.py', '--source',
                str(PACKAGE/'source/ServerRack_Authored.glb'), '--record', str(PACKAGE/'appraisal.json'))
            for view, eye in [('front', '10,6,14'), ('rear', '-10,6,-14')]:
                run('render-'+view, 'tools/blender/preview_scene.py', '--asset', 'server-rack',
                    '--materials', 'original', '--no-arena', '--eye='+eye, '--look', '0,4,0',
                    '--lens', '52', '--resolution', '720,840', '--samples', '48',
                    '--ground', '200', '--ground-y=-0.05', '--out',
                    str(PACKAGE/f'review/prototype-{view}.png'))
        report['filesSha256'] = validate()
        report['status'] = 'passed'
        report['limitations'] = ['File checks do not establish Studio import or visual approval.',
                                  'Check-only hashes existing previews; it does not regenerate them.']
    except Exception as exc:
        report['status'] = 'failed'
        report['error'] = str(exc)
        raise
    finally:
        report_path.write_text(json.dumps(report, indent=2)+'\n')
    print('PASS: asset package checked. Studio import and physics setup remain separate.')


if __name__ == '__main__':
    main()
