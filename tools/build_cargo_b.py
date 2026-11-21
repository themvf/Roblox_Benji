"""Rebuild, render and validate the intact white cargo unit; never touches Roblox Studio.

python tools/build_cargo_b.py
python tools/build_cargo_b.py --check-only
Use --blender PATH when Blender is not on PATH or in the usual Windows folder.
Generated outputs are backed up under .mapbuild/cargo-b before a rebuild.

This is the sibling of tools/build_cargo.py, which does the same job for the
destroyed unit. The two are deliberately separate scripts rather than one
parameterised one: each carries its own triangle budget, camera framing and
per-asset remesh tuning, and a shared script would hide which asset a tweak
was for. The shared parts are already shared, in tools/blender/scene_kit.py
and tools/blender/preview_scene.py.
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

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / 'assets/models/cargo-b'
EXPORT = 'exports/CargoUnit.glb'
BUDGET = 8000
HEIGHT = 6.0
# Framed for a unit about 8.2 studs long, 4.9 deep and 6 tall: closer in than the
# destroyed unit's cameras, which are set for a 10.3-stud body.
VIEWS = [('front', '0,4,20'), ('front-quarter', '-12,9,15'),
         ('rear-quarter', '12,8,-15'), ('end', '20,5,0')]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate():
    export = PACKAGE / EXPORT
    doc, blob = gltf_post.read_glb(export)
    count = gltf_post.report(export, 'final')
    if count > BUDGET:
        raise RuntimeError('Cargo unit exceeds its %d-triangle project budget' % BUDGET)
    if len(doc['meshes']) != 1 or len(doc['materials']) != 1:
        raise RuntimeError('Expected one mesh and one material')
    prims = doc['meshes'][0]['primitives']
    if len(prims) != 1 or prims[0].get('mode', 4) != 4:
        raise RuntimeError('Expected one triangle primitive')
    for node in doc['nodes']:
        if any(key in node for key in ('matrix', 'translation', 'rotation', 'scale')):
            raise RuntimeError('Unexpected object transform; recheck scale and pivot')
    pos = doc['accessors'][prims[0]['attributes']['POSITION']]
    lo, hi = pos['min'], pos['max']
    if abs(lo[1]) > 1e-4 or abs(hi[1] - HEIGHT) > 1e-3:
        raise RuntimeError('Expected bottom pivot and %.0f-stud height' % HEIGHT)
    if abs(lo[0] + hi[0]) > 1e-3 or abs(lo[2] + hi[2]) > 1e-3:
        raise RuntimeError('Expected the unit centred on X/Z')
    # The long horizontal axis must be X. build_cargo_b.py rotates the source onto
    # X because scene_kit's fit, the camera framing above and the map author's
    # "wide" reading all assume it; a silent yaw would put the doors on the wrong face.
    if (hi[0] - lo[0]) <= (hi[2] - lo[2]):
        raise RuntimeError('Expected the long axis on X; the source orientation drifted')
    if gltf_post.foreign_textures(doc):
        raise RuntimeError('Unsupported embedded texture format')
    for texture in doc.get('images', []):
        if texture.get('mimeType') != 'image/png':
            raise RuntimeError('Expected embedded PNG textures')
    textures = gltf_post.texture_info(doc, blob)
    if len(textures) != 3 or any(size != (1024, 1024) for _, size in textures):
        raise RuntimeError('Expected colour, metallic-roughness and normal 1024 maps')
    if 'normalTexture' not in doc['materials'][0]:
        raise RuntimeError('Baked normal map is not wired into the material')
    appraisal = json.loads((PACKAGE / 'appraisal.json').read_text(encoding='utf-8'))
    if not appraisal.get('decision'):
        raise RuntimeError('Missing intake decision')
    if appraisal['sourceSha256'] != digest(PACKAGE / 'source/CargoB_Authored.glb'):
        raise RuntimeError('Appraisal is stale: rebuild the package')
    required = [EXPORT, 'source/CargoB.blend', 'source/CargoB_Authored.glb',
                'source/design-reference.png', 'source/trellis-original.glb',
                'source/trellis-reference-appraisal.json',
                'textures/CargoB_Color.png', 'textures/CargoB_Normal.png',
                'textures/CargoB_Roughness.png', 'textures/CargoB_Metalness.png',
                'SetupCargoUnit.luau', 'appraisal.json']
    required += ['review/prototype-%s.png' % view for view, _ in VIEWS]
    return {name: digest(PACKAGE / name) for name in required}, {
        'triangles': count, 'boundsMin': lo, 'boundsMax': hi}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-only', action='store_true')
    parser.add_argument('--blender', type=Path)
    args = parser.parse_args()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    report = {'checkedAtUtc': stamp, 'mode': 'check' if args.check_only else 'rebuild',
              'status': 'running', 'visuallyApproved': False, 'studioVerified': False}
    report_path = PACKAGE / 'validation.json'
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    try:
        if not args.check_only:
            blender = args.blender or shutil.which('blender')
            if not blender and os.name == 'nt':
                candidate = Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Blender Foundation/Blender 4.3/blender.exe'
                if candidate.exists():
                    blender = candidate
            if not blender:
                raise RuntimeError('Blender missing. Supply --blender PATH. Tested with Blender 4.3.2.')
            backup = ROOT / '.mapbuild/cargo-b' / stamp
            backup.mkdir(parents=True)
            for name in ('source', 'exports', 'textures', 'review'):
                if (PACKAGE / name).exists():
                    shutil.copytree(PACKAGE / name, backup / name)
            if (PACKAGE / 'appraisal.json').exists():
                shutil.copy2(PACKAGE / 'appraisal.json', backup / 'appraisal.json')
            report['backup'] = str(backup.relative_to(ROOT))

            def run(label, script, *arguments):
                command = [str(blender), '--factory-startup', '-b', '--python-exit-code', '1',
                           '--python', script]
                if arguments:
                    command += ['--', *arguments]
                print(label, flush=True)
                with (backup / (label + '.log')).open('w', encoding='utf-8') as log:
                    subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                   check=True, timeout=1800)

            # The appraisal decision is human-authored; keep it across re-records.
            decision = None
            if (PACKAGE / 'appraisal.json').exists():
                decision = json.loads((PACKAGE / 'appraisal.json').read_text(encoding='utf-8')).get('decision')
            run('author', 'tools/blender/build_cargo_b.py')
            run('export', 'tools/blender/scene_kit.py', '--asset', 'cargo-b')
            run('appraise', 'tools/blender/appraise_asset.py', '--source',
                str(PACKAGE / 'source/CargoB_Authored.glb'), '--record', str(PACKAGE / 'appraisal.json'))
            if decision:
                appraisal = json.loads((PACKAGE / 'appraisal.json').read_text(encoding='utf-8'))
                appraisal['decision'] = decision
                (PACKAGE / 'appraisal.json').write_text(json.dumps(appraisal, indent=2) + '\n')
            for view, eye in VIEWS:
                run('render-' + view, 'tools/blender/preview_scene.py', '--asset', 'cargo-b',
                    '--materials', 'original', '--no-arena', '--eye=' + eye, '--look', '0,2.8,0',
                    '--lens', '40', '--resolution', '960,640', '--samples', '48',
                    '--ground', '200', '--ground-y=-0.05', '--out',
                    str(PACKAGE / f'review/prototype-{view}.png'))
        report['filesSha256'], report['measured'] = validate()
        report['status'] = 'passed'
        report['limitations'] = ['File checks do not establish visual approval or Studio import.',
                                 'Check-only hashes existing previews; it does not regenerate them.',
                                 'Height and role are provisional until the user approves them.']
    except Exception as exc:
        report['status'] = 'failed'
        report['error'] = str(exc)
        raise
    finally:
        report_path.write_text(json.dumps(report, indent=2) + '\n')
    print('PASS: cargo-b package checked. Visual approval and Studio import remain separate.')


if __name__ == '__main__':
    main()
