"""One finishing pass for a kit-look piece, from its 3D shape: Tripo's paint becomes the look's
steel palette, worn bright edges go on every ridge, glow goes into every crevice, and the result
is baked back into the piece's own texture (its UVs are kept).

    blender -b -noaudio --python tools/blender/finish_piece.py -- <piece.glb> <out.png> <spec.json>

spec.json:
    {"size": 2048,
     "steel": [[position, [r, g, b]], ...],   sRGB stops by brightness, measured from a piece
                                              that already looks right (kit_look.py finish)
     "edge": 0.75, "edgeColor": [r, g, b],    how strongly ridges are lit, and with what
     "glow": "#FF7A1E", "glowAmount": 0.85,   colour baked into crevices (Roblox cannot make a
                                              texture glow; this is paint, like the other plates)
     "edgeRadius": 0.012, "cavity": 0.035,   as fractions of the piece's largest dimension
     "keepPaint": false,                      keep the piece's own colours instead of `steel`
     "grain": "<png>", "grainScale": 6,       a detail picture laid over every side (overlay)
     "grainAmount": 0.8}

Why from the shape, not the picture: the knight's helmet was cut from the concept, which painted
a warm rim light onto it as flat copper. Recolouring that picture in 2D (glb_matte.retint) fixed
the hue, but its seams could only follow the few gaps the paint happened to show. Edges and
crevices found on the mesh follow the real plates. Cycles only (Bevel and AO are Cycles nodes,
and EEVEE has no GPU here).
"""

import json
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
source, out, spec = argv[0], argv[1], json.loads(open(argv[2], encoding="utf-8").read())
size = spec.get("size", 2048)


def linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_linear(text):
    return tuple(linear(int(text[i:i + 2], 16) / 255) for i in (1, 3, 5))


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = spec.get("samples", 24)

bpy.ops.import_scene.gltf(filepath=source)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
obj = meshes[0]
bpy.context.view_layer.objects.active = obj
largest = max(obj.dimensions)

material = obj.active_material
nodes, links = material.node_tree.nodes, material.node_tree.links
paint = next(n.image for n in nodes if n.type == "TEX_IMAGE" and n.image)
for node in list(nodes):
    nodes.remove(node)


# A Mix node set to RGBA keeps float and vector sockets too, all named A and B: its colour
# inputs are 6 and 7 and its colour output is 2. Factor is input 0.
def node(kind, x, y, **settings):
    made = nodes.new(kind)
    made.location = (x, y)
    for key, value in settings.items():
        setattr(made, key, value)
    return made


texture = node("ShaderNodeTexImage", -1200, 300, image=paint)
uv = node("ShaderNodeUVMap", -1400, 300)
links.new(uv.outputs["UV"], texture.inputs["Vector"])

# 1. Tripo's light and shade, in the steel palette: brightness picks the colour.
bright = node("ShaderNodeRGBToBW", -950, 300)
links.new(texture.outputs["Color"], bright.inputs["Color"])
steel = node("ShaderNodeValToRGB", -750, 300)
ramp = steel.color_ramp
stops = spec["steel"]
while len(ramp.elements) < len(stops):
    ramp.elements.new(0.5)
for element, (position, colour) in zip(ramp.elements, stops):
    element.position = linear(position)
    element.color = (*(linear(c) for c in colour), 1)
links.new(bright.outputs["Val"], steel.inputs["Fac"])
base = steel.outputs["Color"]
if spec.get("keepPaint"):  # leather, not steel: keep the model's own paint (a whole-body look)
    base = texture.outputs["Color"]
if spec.get("grain"):
    # 1b. Leather grain from a real picture, projected from all six sides in the model's own
    # space, so it covers faces the picture never showed: the Bouncer's back came out of Tripo
    # with no paint on it but flat dark leather.
    coords = node("ShaderNodeTexCoord", -1400, 600)
    tile = node("ShaderNodeMapping", -1250, 600)
    tile.inputs["Scale"].default_value = [spec.get("grainScale", 6.0)] * 3
    links.new(coords.outputs["Object"], tile.inputs["Vector"])
    grain = node("ShaderNodeTexImage", -1050, 600, image=bpy.data.images.load(spec["grain"]),
                 projection="BOX", projection_blend=0.3)
    grain.image.colorspace_settings.name = "Non-Color"
    links.new(tile.outputs["Vector"], grain.inputs["Vector"])
    grained = node("ShaderNodeMix", -550, 450, data_type="RGBA", blend_type="OVERLAY")
    grained.inputs[0].default_value = spec.get("grainAmount", 0.8)
    links.new(base, grained.inputs[6])
    links.new(grain.outputs["Color"], grained.inputs[7])
    base = grained.outputs[2]

# 2. Worn edges: where a rounded normal (Bevel) leaves the true one, the surface turns a ridge.
geometry = node("ShaderNodeNewGeometry", -1200, -100)
bevel = node("ShaderNodeBevel", -1200, -300, samples=8)
bevel.inputs["Radius"].default_value = spec.get("edgeRadius", 0.012) * largest
dot = node("ShaderNodeVectorMath", -950, -200, operation="DOT_PRODUCT")
links.new(geometry.outputs["Normal"], dot.inputs[0])
links.new(bevel.outputs["Normal"], dot.inputs[1])
ridge = node("ShaderNodeMapRange", -750, -200)
ridge.inputs["From Min"].default_value = spec.get("ridgeStart", 0.995)
ridge.inputs["From Max"].default_value = spec.get("ridgeFull", 0.93)
links.new(dot.outputs["Value"], ridge.inputs["Value"])
convex = node("ShaderNodeMath", -550, -200, operation="MULTIPLY")
pointy = node("ShaderNodeMapRange", -750, -400)  # only outward ridges, not inside corners
pointy.inputs["From Min"].default_value = 0.49
pointy.inputs["From Max"].default_value = 0.53
links.new(geometry.outputs["Pointiness"], pointy.inputs["Value"])
links.new(ridge.outputs["Result"], convex.inputs[0])
links.new(pointy.outputs["Result"], convex.inputs[1])
edge_amount = node("ShaderNodeMath", -350, -200, operation="MULTIPLY")
edge_amount.inputs[1].default_value = spec.get("edge", 0.75)
links.new(convex.outputs["Value"], edge_amount.inputs[0])
edged = node("ShaderNodeMix", -150, 200, data_type="RGBA")
edged.inputs[7].default_value = (*(linear(c) for c in spec.get("edgeColor", stops[-1][1])), 1)
links.new(edge_amount.outputs["Value"], edged.inputs[0])
links.new(base, edged.inputs[6])

# 3. Glow in crevices: narrow gaps are dark to a short ambient-occlusion test.
occlusion = node("ShaderNodeAmbientOcclusion", -950, -600, only_local=True, samples=16)
occlusion.inputs["Distance"].default_value = spec.get("cavity", 0.035) * largest
crevice = node("ShaderNodeMapRange", -750, -600)
crevice.inputs["From Min"].default_value = spec.get("creviceStart", 0.55)
crevice.inputs["From Max"].default_value = spec.get("creviceFull", 0.2)
links.new(occlusion.outputs["AO"], crevice.inputs["Value"])
glow_amount = node("ShaderNodeMath", -550, -600, operation="MULTIPLY")
glow_amount.inputs[1].default_value = spec.get("glowAmount", 0.85)
links.new(crevice.outputs["Result"], glow_amount.inputs[0])
glowed = node("ShaderNodeMix", 50, 200, data_type="RGBA")
glowed.inputs[7].default_value = (*hex_linear(spec.get("glow", "#FF7A1E")), 1)
links.new(glow_amount.outputs["Value"], glowed.inputs[0])
links.new(edged.outputs[2], glowed.inputs[6])

final = glowed.outputs[2]
if spec.get("stitch"):
    # Stitching: dashes along the rim of every crease (where the short occlusion test is just
    # starting to darken), the "visible stitching" of the Bouncer's texture line. The dashes
    # are a fine wave in the piece's own space, so they run across a seam, not along the UVs.
    rim = node("ShaderNodeMapRange", -550, -850)
    rim.inputs["From Min"].default_value = spec.get("stitchFrom", 0.62)
    rim.inputs["From Max"].default_value = spec.get("stitchTo", 0.5)
    rim.clamp = True
    links.new(occlusion.outputs["AO"], rim.inputs["Value"])
    beyond = node("ShaderNodeMapRange", -550, -1000)  # not deep in the crease itself
    beyond.inputs["From Min"].default_value = spec.get("stitchTo", 0.5) - 0.02
    beyond.inputs["From Max"].default_value = spec.get("stitchTo", 0.5) - 0.12
    beyond.inputs["To Min"].default_value = 1.0
    beyond.inputs["To Max"].default_value = 0.0
    beyond.clamp = True
    links.new(occlusion.outputs["AO"], beyond.inputs["Value"])
    space = node("ShaderNodeTexCoord", -1200, -1150)
    dashes = node("ShaderNodeTexWave", -950, -1150, wave_type="RINGS")
    dashes.inputs["Scale"].default_value = spec.get("stitchScale", 150.0) / largest  # about 60 dashes per piece height
    links.new(space.outputs["Object"], dashes.inputs["Vector"])
    gap = node("ShaderNodeMapRange", -750, -1150)
    gap.inputs["From Min"].default_value = 0.55
    gap.inputs["From Max"].default_value = 0.65
    gap.clamp = True
    links.new(dashes.outputs["Fac"], gap.inputs["Value"])
    seam = node("ShaderNodeMath", -350, -900, operation="MULTIPLY")
    links.new(rim.outputs["Result"], seam.inputs[0])
    links.new(beyond.outputs["Result"], seam.inputs[1])
    stitch = node("ShaderNodeMath", -150, -900, operation="MULTIPLY")
    links.new(seam.outputs["Value"], stitch.inputs[0])
    links.new(gap.outputs["Result"], stitch.inputs[1])
    amount = node("ShaderNodeMath", 0, -900, operation="MULTIPLY")
    amount.inputs[1].default_value = spec["stitch"]
    links.new(stitch.outputs["Value"], amount.inputs[0])
    stitched = node("ShaderNodeMix", 150, 0, data_type="RGBA")
    stitched.inputs[7].default_value = (*(linear(c) for c in spec.get("stitchColor", [0.6, 0.55, 0.45])), 1)
    links.new(amount.outputs["Value"], stitched.inputs[0])
    links.new(final, stitched.inputs[6])
    final = stitched.outputs[2]
emit = node("ShaderNodeEmission", 250, 200)
links.new(final, emit.inputs["Color"])
output = node("ShaderNodeOutputMaterial", 450, 200)
links.new(emit.outputs["Emission"], output.inputs["Surface"])

# 4. Bake into a fresh image on the piece's own UVs.
target = bpy.data.images.new("finished", size, size, alpha=False)
holder = node("ShaderNodeTexImage", 250, -100, image=target)
nodes.active = holder
for other in bpy.data.objects:
    other.select_set(other == obj)
scene.cycles.bake_type = "EMIT"
scene.render.bake.margin = 8
bpy.ops.object.bake(type="EMIT")
target.filepath_raw = out
target.file_format = "PNG"
target.save()
print("FINISHED", out, size)
