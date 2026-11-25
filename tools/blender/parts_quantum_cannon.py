"""Hand-modelled muzzle for the Quantum Cannon's Meshy scan, added by scene_kit's `extraParts` step.

The scan got the body right and the muzzle wrong: an eight-sided lumpy rim, a flat triangle in the
bore, and the glow ring painted into the texture, so it could not glow. These three lathed pieces sit
over the scan's muzzle face and replace what is seen there:

    MuzzleRim  a round black rim with a stepped lip, covering the scan's rim
    MuzzleBore a dark cup with a conical throat, so the bore reads deep
    Glow       the ring on the shelf inside the lip, its own mesh so Studio can make it Neon

Frame: the exported model's frame after `pivot` (Blender, Z up, muzzle toward -Y). The centre and
radius were measured on the scan export on 2026-11-22: face at y = -2.316, axis at x 0, z 0.05,
outer rim radius 0.46. Profiles are (d, r): d is depth back into the gun from the face, r the radius.
"""

import math
from pathlib import Path

import bmesh
import bpy

ROOT = Path(__file__).resolve().parents[2]
PALETTE_PNG = ROOT / "assets/models/quantum-cannon/textures/QuantumCannonParts_Palette.png"

FACE_Y = -2.316
AXIS_X, AXIS_Z = 0.0, 0.05
SIDES = 18  # round enough at arm's length; every triangle here is one the scan body loses

PALETTE = [("black", (30, 30, 33)), ("bore", (8, 8, 10)), ("glow", (236, 244, 255)), ("spare", (0, 0, 0))]
COLS, SWATCH = 4, 8


def lathe(name, profile, colour, closed=False):
    """Revolve (d, r) round the bore axis. r == 0 is one vertex on the axis; closed joins last to first."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rings = []
    for d, r in profile:
        y = FACE_Y + d
        if r <= 1e-6:
            rings.append(bm.verts.new((AXIS_X, y, AXIS_Z)))
        else:
            rings.append(
                [bm.verts.new((AXIS_X + r * math.cos(2 * math.pi * k / SIDES), y, AXIS_Z + r * math.sin(2 * math.pi * k / SIDES))) for k in range(SIDES)]
            )
    pairs = list(zip(rings, rings[1:]))
    if closed:
        pairs.append((rings[-1], rings[0]))
    faces = []
    for a, b in pairs:
        for k in range(SIDES):
            n = (k + 1) % SIDES
            if isinstance(a, list) and isinstance(b, list):
                faces.append(bm.faces.new((a[k], a[n], b[n], b[k])))
            elif isinstance(a, list):
                faces.append(bm.faces.new((a[k], a[n], b)))
            else:
                faces.append(bm.faces.new((a, b[n], b[k])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    i = [p[0] for p in PALETTE].index(colour)
    for face in faces:
        for loop in face.loops:
            loop[uv].uv = ((i + 0.5) / COLS, 0.5)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def palette_image():
    width, height = COLS * SWATCH, SWATCH
    pixels = []
    for _ in range(height):
        for col in range(width):
            rgb = PALETTE[col // SWATCH][1]
            pixels += [c / 255 for c in rgb] + [1.0]
    image = bpy.data.images.new("QuantumCannonParts_Palette", width, height, alpha=False)
    image.pixels = pixels
    PALETTE_PNG.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(PALETTE_PNG)
    image.file_format = "PNG"
    image.save()
    return bpy.data.images.load(str(PALETTE_PNG), check_existing=False)


def material(image, name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.45
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def add(final):
    image = palette_image()
    rim = lathe(
        "MuzzleRim",
        [(0.30, 0.47), (0.0, 0.47), (-0.03, 0.445), (-0.03, 0.405), (0.01, 0.395), (0.01, 0.33), (0.30, 0.30)],
        "black",
        closed=True,
    )
    # A short cone: deep enough to read as a bore, shallow enough to hide the scan's own bore floor behind it.
    bore = lathe("MuzzleBore", [(0.30, 0.0), (0.30, 0.335), (0.02, 0.335), (0.02, 0.31), (0.09, 0.25), (0.17, 0.0)], "bore")
    glow = lathe("Glow", [(-0.012, 0.34), (0.008, 0.34), (0.008, 0.392), (-0.012, 0.392)], "glow", closed=True)
    rim.data.materials.append(material(image, "QuantumCannonMuzzle"))
    bore.data.materials.append(rim.data.materials[0])
    glow.data.materials.append(material(image, "QuantumCannonGlow"))
    return [rim, bore, glow]
