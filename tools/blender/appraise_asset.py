"""Appraise a source asset BEFORE building a pipeline around it.

Answers one question: what is this thing actually fit for in Roblox -- an in-game
prop, a skybox source, or nothing? Four rounds of rework on the Snow Fortress
horizon came from not asking it, so this runs first now.

    blender -b -noaudio --python tools/blender/appraise_asset.py -- --source "<file>"
    blender -b -noaudio --python tools/blender/appraise_asset.py -- --source "<file>" --texture "<png>"

What it measures and why each one decides something:

  triangles        Roblox caps a mesh at 10,000. The ratio you must decimate by
                   predicts whether the silhouette survives; past ~90% it will not.
  relief ratio     height / longest horizontal span. Under ~0.2 a form reads as a
                   flat plate from any distance, so it cannot be a mountain.
  open boundary    a heightfield is a single sheet. Sheets show their underside from
                   below and a cliff at every edge, and no placement hides either.
  overhangs        whether the surface is single-valued from above, i.e. whether it
                   is a terrain scan rather than a modelled form.
  uv / texture     a top-down bake smears when the asset is seen from the side.

The verdict is advice, not a gate. Read the numbers.
"""

import argparse
import math
import os
import sys

import bpy
import bmesh
import mathutils

TRI_LIMIT = 10000
FLAT_RELIEF = 0.20
SILHOUETTE_RISK = 0.90  # decimating away more of the mesh than this loses the outline


def load(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    else:
        raise SystemExit("unsupported source format: " + ext)
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="appraise_asset")
    ap.add_argument("--source", required=True)
    ap.add_argument("--texture")
    args = ap.parse_args(argv)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    meshes = load(args.source)
    if not meshes:
        raise SystemExit("no meshes found")
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    mesh = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces)

    tris = len(bm.faces)
    open_edges = sum(1 for e in bm.edges if len(e.link_faces) < 2)
    nonmanifold = sum(1 for e in bm.edges if len(e.link_faces) > 2)

    co = [v.co for v in bm.verts]
    mn = [min(c[i] for c in co) for i in range(3)]
    mx = [max(c[i] for c in co) for i in range(3)]
    span = [mx[i] - mn[i] for i in range(3)]
    up = span.index(min(span))
    ground = [i for i in range(3) if i != up]
    longest = max(span[ground[0]], span[ground[1]])
    relief = span[up] / longest if longest else 0.0

    # Overhang test: a heightfield's faces all point the same way along `up`.
    downward = 0
    for f in bm.faces:
        if f.normal[up] < -0.05:
            downward += 1
    overhang_ratio = downward / max(tris, 1)
    bm.free()
    bpy.data.meshes.remove(mesh)

    uvs = [layer.name for layer in ob.data.uv_layers]

    print("")
    print("asset      %s" % os.path.basename(args.source))
    print("triangles  %s  (Roblox caps a mesh at %s)" % (format(tris, ","), format(TRI_LIMIT, ",")))
    if tris > TRI_LIMIT:
        cut = 1 - TRI_LIMIT / tris
        print("           must lose %.1f%% to fit one mesh%s"
              % (cut * 100, "  <-- silhouette will not survive" if cut > SILHOUETTE_RISK else ""))
    # `up` is only a guess: the thinnest axis. That is right for a terrain plate and
    # wrong for, say, a wide winged prop, so relief only means something once the
    # one-sided test below says this really is a height field.
    print("size       %.2f x %.2f x %.2f (thinnest axis is %s)" % (span[0], span[1], span[2], "xyz"[up]))
    print("relief     %.3f  (thinnest / longest span)%s"
          % (relief, "  <-- reads FLAT at any distance" if relief < FLAT_RELIEF else ""))
    print("open edges %s%s" % (format(open_edges, ","),
          "  (not watertight; only matters if it is a height field)" if open_edges else "  (closed solid)"))
    if nonmanifold:
        print("           %s non-manifold edges; Solidify and booleans will shred these"
              % format(nonmanifold, ","))
    # A height field's faces all point the same way along `up`. Which way depends
    # on the exporter's winding, so test for "one-sided" rather than for "upward".
    one_sided = min(overhang_ratio, 1 - overhang_ratio) < 0.02
    print("overhangs  %.1f%% of faces point downward%s"
          % (overhang_ratio * 100, "  <-- one-sided: a height field, i.e. a top-down scan" if one_sided else ""))
    print("uv layers  %s" % (", ".join(uvs) if uvs else "NONE -- cannot be textured"))

    print("")
    verdicts = []
    if one_sided and open_edges:
        verdicts.append("A height field, not a model: single-valued from above, so it has no")
        verdicts.append("  sides and no underside. It was authored to be looked down on.")
    if relief < FLAT_RELIEF and one_sided:
        verdicts.append("NOT a horizon. This is a flat sheet: from the side it shows its")
        verdicts.append("  underside and an edge cliff, and its bake smears. Use it viewed from")
        verdicts.append("  above, or as a source inside a skybox render, never as side-on geometry.")
    if tris > TRI_LIMIT and (1 - TRI_LIMIT / tris) > SILHOUETTE_RISK:
        verdicts.append("Too dense for in-game geometry without losing its shape. If the shape is")
        verdicts.append("  the point, render it to a skybox instead, where detail is free.")
    if not open_edges and relief >= FLAT_RELIEF and tris <= TRI_LIMIT * 4:
        verdicts.append("Good prop candidate: closed, has depth, and decimates gently.")
        verdicts.append("  Build it with tools/blender/scene_kit.py.")
    if not uvs:
        verdicts.append("No UVs, so it can only ever be flat-shaded.")
    if not verdicts:
        verdicts.append("No blocking problems found. Check it against the intent anyway:")
        verdicts.append("  a horizon needs silhouette, a prop needs to read from every angle.")
    print("verdict")
    for line in verdicts:
        print("  " + line)
    print("")


main()
