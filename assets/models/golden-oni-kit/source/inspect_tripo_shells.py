"""Measure connected components in the generator's coordinate frame."""
import json
import math
from pathlib import Path
import bpy
import bmesh
from mathutils import Matrix, Vector

root = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root / 'tripo-multiview.glb'))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.object
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
obj.data.transform(Matrix.Rotation(math.radians(-90), 4, 'Z'))
coords = [v.co.copy() for v in obj.data.vertices]
lo = Vector([min(p[i] for p in coords) for i in range(3)])
hi = Vector([max(p[i] for p in coords) for i in range(3)])
obj.data.transform(Matrix.Translation(Vector((-(lo.x+hi.x)/2, -(lo.y+hi.y)/2, -lo.z))))
bm=bmesh.new(); bm.from_mesh(obj.data); bmesh.ops.remove_doubles(bm,verts=bm.verts[:],dist=1e-5)
bm.faces.ensure_lookup_table(); bm.faces.index_update()
seen=set(); found=[]
for face in bm.faces:
    if face.index in seen: continue
    stack=[face]; seen.add(face.index); component=[]
    while stack:
        f=stack.pop(); component.append(f)
        for edge in f.edges:
            for nxt in edge.link_faces:
                if nxt.index not in seen:
                    seen.add(nxt.index); stack.append(nxt)
    verts={v for f in component for v in f.verts}
    bounds=[[round(min(v.co[i] for v in verts),4),round(max(v.co[i] for v in verts),4)] for i in range(3)]
    found.append({'faces':len(component),'bounds':bounds})
print('SHELLS',json.dumps(sorted(found,key=lambda v:-v['faces'])))
bm.free()
