"""Author the futuristic office desk. Run with Blender --factory-startup -b.

Clean rebuild of the Midjourney reference (assets/models/desk/source/
design-reference.png). The TRELLIS GLB is kept only as a 3D reference: its
decimation to one Roblox mesh shredded the surfaces (review/trellis-decimate-9000.png).

Blender axes: X = length, Y = depth (front faces -Y, glTF +Z), Z = up.
Side profiles are traced from the reference at about 0.0155 studs per pixel,
so the desk is 14 studs long with its work surface at about 2.95 studs.
"""
from pathlib import Path
import json
import math
import bmesh
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/desk'
LENGTH = 14.0
bpy.ops.wm.read_factory_settings(use_empty=True)
for sub in ('source', 'textures', 'exports', 'review'):
    (OUT / sub).mkdir(parents=True, exist_ok=True)

# ---- one shared material atlas (pixels are bottom-up, Blender UV space) ----
N = 1024
color = np.ones((N, N, 4), dtype=np.float32)
rough = np.ones((N, N, 4), dtype=np.float32)
metal = np.ones((N, N, 4), dtype=np.float32)
color[:, :, :3] = (0.85, 0.82, 0.75)
rough[:, :, :3] = 0.45
metal[:, :, :3] = 0.0
# Swatches, 128 px each on the bottom row: (sRGB colour, roughness, metalness)
SW = {
    'shell': ((0.85, 0.82, 0.75), 0.42, 0.0),   # warm off-white body
    'panel': ((0.79, 0.76, 0.70), 0.48, 0.0),   # door / inset panels
    'seam': ((0.46, 0.45, 0.42), 0.60, 0.0),    # panel gaps
    'glass': ((0.035, 0.04, 0.045), 0.12, 0.0),  # tablet / dark glass
    'rubber': ((0.10, 0.10, 0.10), 0.85, 0.0),  # feet
    'red': ((0.85, 0.10, 0.08), 0.30, 0.0),     # indicator
    'metal': ((0.66, 0.66, 0.64), 0.30, 0.8),   # knob / puck
    'under': ((0.70, 0.68, 0.63), 0.50, 0.0),   # shaded underside beam
}
SLOT = {}
for i, (key, (rgb, r, m)) in enumerate(SW.items()):
    color[:128, i*128:(i+1)*128, :3] = rgb
    rough[:128, i*128:(i+1)*128, :3] = r
    metal[:128, i*128:(i+1)*128, :3] = m
    SLOT[key] = ((i*128+64)/N, 64/N)
# Pod display (rows 256..512): dark glass, dim readout blocks, bezel.
D0, D1 = 256, 512
color[D0:D1, :, :3] = (0.05, 0.055, 0.06)
rough[D0:D1, :, :3] = 0.15
color[D0:D0+10, :, :3] = color[D1-10:D1, :, :3] = (0.30, 0.30, 0.29)
color[:, :, :3][D0:D1, :10] = color[:, :, :3][D0:D1, -10:] = (0.30, 0.30, 0.29)
color[D0+120:D0+190, 40:300, :3] = (0.17, 0.18, 0.19)       # readout
color[D0+60:D0+90, 40:520, :3] = (0.11, 0.12, 0.13)         # status bar
for x in range(620, 980, 40):                               # vent slots
    color[D0+40:D0+216, x:x+18, :3] = (0.02, 0.022, 0.025)
# Tablet (rows 576..832): glass with a faint edge highlight.
T0, T1 = 576, 832
color[T0:T1, :, :3] = (0.035, 0.04, 0.045)
rough[T0:T1, :, :3] = 0.10
color[T0:T0+6, :, :3] = color[T1-6:T1, :, :3] = (0.16, 0.17, 0.18)
color[T0+30:T0+36, 60:960, :3] = (0.09, 0.10, 0.11)


def image(name, data, data_map=False):
    img = bpy.data.images.new(name, width=N, height=N, alpha=True)
    if data_map:
        img.colorspace_settings.name = 'Non-Color'
    img.pixels.foreach_set(np.clip(data, 0, 1).ravel())
    img.filepath_raw = str(OUT / 'textures' / (name + '.png'))
    img.file_format = 'PNG'
    img.save()
    return img


mat = bpy.data.materials.new('Desk_SharedAtlas')
mat.use_nodes = True
nodes, links = mat.node_tree.nodes, mat.node_tree.links
bsdf = nodes.get('Principled BSDF')
for name, data, socket, is_data in [('Desk_Color', color, 'Base Color', False),
                                     ('Desk_Roughness', rough, 'Roughness', True),
                                     ('Desk_Metalness', metal, 'Metallic', True)]:
    tex = nodes.new('ShaderNodeTexImage')
    tex.image = image(name, data, is_data)
    links.new(tex.outputs['Color'], bsdf.inputs[socket])

source = bpy.data.collections.new('SOURCE')
bpy.context.scene.collection.children.link(source)
parts = []


# ---- geometry helpers ----
def fillet(points):
    """[(x, z, radius)] closed polygon -> list of (x, z) with rounded corners."""
    out = []
    n = len(points)
    for i, (px, pz, r) in enumerate(points):
        p = Vector((px, pz))
        if r <= 0:
            out.append(p)
            continue
        a = Vector(points[i-1][:2]); b = Vector(points[(i+1) % n][:2])
        u = (a-p).normalized(); v = (b-p).normalized()
        theta = math.acos(max(-1, min(1, u.dot(v))))
        t = r / math.tan(theta/2)
        t = min(t, (a-p).length*.49, (b-p).length*.49)
        r = t * math.tan(theta/2)
        centre = p + (u+v).normalized() * (r/math.sin(theta/2))
        s, e = p+u*t, p+v*t
        a0 = math.atan2(s.y-centre.y, s.x-centre.x)
        a1 = math.atan2(e.y-centre.y, e.x-centre.x)
        sweep = (a1-a0+math.pi) % (2*math.pi) - math.pi
        steps = max(2, int(abs(sweep)/math.radians(15)))
        for k in range(steps+1):
            ang = a0 + sweep*k/steps
            out.append(centre + Vector((math.cos(ang), math.sin(ang)))*r)
    return out


def finish(ob, name, swatch, uv_region=None):
    """Link into SOURCE, assign atlas UVs. uv_region=(v0, v1) maps -Y faces."""
    ob.name = name
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    source.objects.link(ob)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    me = ob.data
    uv = me.uv_layers.active or me.uv_layers.new(name='UVMap')
    lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if uv_region and poly.normal.y < -.9:
                u = (co.x-lo.x)/max(hi.x-lo.x, 1e-6)
                v = (co.z-lo.z)/max(hi.z-lo.z, 1e-6)
                uv.data[li].uv = (.01+u*.98, (uv_region[0]+v*(uv_region[1]-uv_region[0]))/N)
            elif uv_region and poly.normal.z > .9:
                u = (co.x-lo.x)/max(hi.x-lo.x, 1e-6)
                v = (co.y-lo.y)/max(hi.y-lo.y, 1e-6)
                uv.data[li].uv = (.01+u*.98, (uv_region[0]+v*(uv_region[1]-uv_region[0]))/N)
            else:
                uv.data[li].uv = SLOT[swatch]
    parts.append(ob)
    return ob


def new_object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def smooth(ob, bevel=0.0, segments=3):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    if bevel:
        mod = ob.modifiers.new('Rounded edge', 'BEVEL')
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = 'ANGLE'
        mod.angle_limit = math.radians(40)
        mod.harden_normals = True
        mod.miter_outer = 'MITER_ARC'
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(38), keep_sharp_edges=True)


def profile(name, pts, y0, y1, swatch, bevel=.08, uv_region=None, segments=3):
    """Extrude a filleted XZ side profile between depths y0..y1."""
    ring = fillet(pts)
    bm = bmesh.new()
    front = [bm.verts.new((p.x, y0, p.y)) for p in ring]
    back = [bm.verts.new((p.x, y1, p.y)) for p in ring]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(ring)
    for i in range(n):
        j = (i+1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_object(name, bm)
    smooth(ob, bevel, segments)
    return finish(ob, name, swatch, uv_region)


def plate(name, x0, x1, y0, y1, z0, z1, swatch, radius=0.0, bevel=.01, uv_region=None):
    """Box with optional rounded corners in plan (XY)."""
    r = min(radius, (x1-x0)*.49, (y1-y0)*.49)
    pts = [(x0, y0, r), (x1, y0, r), (x1, y1, r), (x0, y1, r)]
    ring = fillet(pts)
    bm = bmesh.new()
    bot = [bm.verts.new((p.x, p.y, z0)) for p in ring]
    top = [bm.verts.new((p.x, p.y, z1)) for p in ring]
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    for i in range(len(ring)):
        j = (i+1) % len(ring)
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_object(name, bm)
    smooth(ob, bevel, 1)
    return finish(ob, name, swatch, uv_region)


def front_plate(name, x0, x1, z0, z1, y, thick, swatch, radius=0.0, bevel=.01, uv_region=None):
    """Rounded rectangle in the XZ plane, standing proud of a -Y facing surface."""
    r = min(radius, (x1-x0)*.49, (z1-z0)*.49)
    return profile(name, [(x0, z0, r), (x1, z0, r), (x1, z1, r), (x0, z1, r)],
                   y-thick, y, swatch, bevel, uv_region, segments=1)


def puck(name, x, y, z, radius, height, swatch, verts=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=height,
                                        location=(x, y, z+height/2))
    ob = bpy.context.object
    smooth(ob, min(.02, height*.3), 2)
    return finish(ob, name, swatch)


# ---- main shell: work surface sweeping down into the right-hand leg ----
DEPTH = 4.0
Y0, Y1 = -DEPTH/2, DEPTH/2
TOP = 2.95
shell = [
    (-7.00, 2.52, .14), (-6.95, TOP-.03, .16),       # rounded left nose
    (7.00, TOP, 1.55),                               # big sweep into the leg
    (7.00, 0.20, .30),                               # outer foot corner
    (4.30, 0.20, .22),                               # inner foot corner
    (2.40, 2.45, .55),                               # concave knee under slab
]
profile('Shell', shell, Y0, Y1, 'shell', bevel=.10)
# Leg door: rounded panel standing slightly proud on front and rear.
for y in (Y0, Y1+.035):  # front plate spans y-thick..y
    front_plate('LegDoor', 4.25, 6.55, .45, 1.95, y, .035, 'panel', radius=.28, bevel=.012)
front_plate('DoorPull', 6.28, 6.36, 1.00, 1.30, Y0-.035, .02, 'seam', radius=.03, bevel=.005)
# Panel seams across the work surface and down the front/rear edges.
for x in (-5.3, 0.45, 3.3):
    plate('TopSeam', x-.02, x+.02, Y0+.14, Y1-.14, TOP-.004, TOP+.004, 'seam', bevel=0)
    for y in (Y0-.004, Y1+.004):
        plate('EdgeSeam', x-.02, x+.02, y-.004, y+.004, 2.62, TOP-.10, 'seam', bevel=0)
# Long accent line along the slab's front and rear faces.
for y in (Y0, Y1):
    plate('SlabLine', -6.75, 5.2, y-.004, y+.004, 2.58, 2.61, 'seam', bevel=0)
# Underside beam linking the pod and the leg.
profile('UnderBeam', [(-2.3, 1.85, .2), (2.7, 1.85, .2), (2.7, 2.46, 0), (-2.3, 2.46, 0)],
        -1.1, 1.1, 'under', bevel=.06)
for y in (-1.1, 1.1+.02):
    front_plate('BeamPanel', -1.2, 0.9, 1.97, 2.30, y, .02, 'panel', radius=.08, bevel=.006)
    front_plate('BeamPanel', 1.1, 2.3, 1.97, 2.30, y, .02, 'panel', radius=.08, bevel=.006)

# ---- left drawer pod ----
PD0, PD1 = -1.75, 1.75
pod = [
    (-7.75, 0.12, .45), (-3.35, 0.12, .30), (-2.55, 1.20, .35), (-1.90, 1.48, .18),
    (-1.90, 1.95, .16), (-2.40, 2.12, .10), (-7.75, 2.12, .45),
]
profile('Pod', pod, PD0, PD1, 'shell', bevel=.16)
plate('PodNeck', -5.9, -3.2, -1.3, 1.3, 2.0, 2.56, 'under', radius=.35, bevel=.04)
front_plate('PodDisplay', -7.30, -4.35, 1.00, 1.55, PD0-.01, .03, 'glass',
            radius=.05, bevel=.01, uv_region=(D0, D1))
plate('PodSeamH', -7.50, -3.60, PD0-.012, PD0+.01, .80, .83, 'seam', bevel=0)
plate('PodSeamV', -4.62, -4.59, PD0-.012, PD0+.01, .14, .81, 'seam', bevel=0)
plate('PodSeamRear', -7.50, -3.60, PD1-.01, PD1+.012, .80, .83, 'seam', bevel=0)
front_plate('PodLED', -5.05, -4.80, .66, .72, PD0-.012, .02, 'red', radius=.02, bevel=.004)
front_plate('PodLatch', -4.35, -4.05, .30, .36, PD0-.012, .02, 'seam', radius=.02, bevel=.004)

# ---- feet (dark rubber plinths set back from the silhouette) ----
plate('PodFoot', -7.35, -3.8, -1.45, 1.45, 0.0, .14, 'rubber', radius=.3, bevel=.02)
plate('LegFoot', 4.45, 6.70, -1.75, 1.75, 0.0, .22, 'rubber', radius=.25, bevel=.02)

# ---- work surface details ----
plate('Tablet', -2.90, -0.85, -1.05, 0.55, TOP-.01, TOP+.018, 'glass', radius=.35,
      bevel=.006, uv_region=(T0, T1))
plate('SidePanel', 2.30, 3.15, -.40, .40, TOP-.01, TOP+.012, 'under', radius=.12, bevel=.005)
puck('Button', -3.65, -0.60, TOP-.01, .09, .05, 'metal', 12)
puck('Button', -4.95, -0.35, TOP-.01, .06, .04, 'seam', 10)
puck('ControlBase', 4.85, 0.45, TOP-.01, .38, .07, 'panel', 24)
puck('ControlKnob', 4.95, 0.45, TOP+.06, .16, .15, 'metal', 16)
plate('ControlArm', 4.35, 4.85, 0.37, 0.53, TOP+.02, TOP+.10, 'metal', radius=.06, bevel=.01)

# ---- join into one production mesh ----
export_collection = bpy.data.collections.new('EXPORT')
bpy.context.scene.collection.children.link(export_collection)
bpy.ops.object.select_all(action='DESELECT')
copies = []
for ob in parts:
    dup = ob.copy(); dup.data = ob.data.copy()
    export_collection.objects.link(dup)
    dup.select_set(True); copies.append(dup)
bpy.context.view_layer.objects.active = copies[0]
bpy.ops.object.join()
export = bpy.context.object
export.name = 'FuturisticDesk'
# Centre on X/Y, floor at Z=0, then scale to exactly LENGTH studs long.
me = export.data
lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
shift = Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z))
scale = LENGTH/(hi.x-lo.x)
for v in me.vertices:
    v.co = (v.co-shift)*scale
export.location = (0, 0, 0)
export['CanCollide'] = False
export['CanTouch'] = False
export['CanQuery'] = False
export['Anchored'] = True
export['Role'] = 'Decoration; futuristic office desk (provisional, awaiting approval)'
source.hide_render = True
source.hide_viewport = True
bpy.context.view_layer.update()
triangles = sum(len(p.vertices)-2 for p in export.data.polygons)
assert triangles < 10000, triangles
assert abs(export.dimensions.x-LENGTH) < 1e-4, export.dimensions[:]
assert len(export.data.materials) == 1
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/Desk.blend'))
bpy.ops.object.select_all(action='DESELECT')
export.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'source/Desk_Authored.glb'),
    export_format='GLB', use_selection=True, export_yup=True, export_apply=True,
    export_extras=True, export_materials='EXPORT', export_image_format='AUTO')
(OUT/'source/build-metrics.json').write_text(json.dumps({
    'triangles': triangles, 'blenderDimensions': [round(d, 4) for d in export.dimensions],
    'lengthStuds': LENGTH, 'workSurfaceStuds': round((TOP-lo.z)*scale, 3),
    'front': 'glTF +Z (Blender -Y)', 'role': 'decoration (provisional)',
    'materialCount': 1, 'surfaceDetail': 'recreated PNG atlas + modelled seams; no source bake',
    'sourceComponents': len(parts)}, indent=2)+'\n')
print('DESK BUILD:', triangles, 'triangles;', [round(d, 3) for d in export.dimensions],
      'Blender dimensions')
