# Snow forest sci-fi command desk prototype

Read [HANDOFF.md](HANDOFF.md) before continuing. The local delivery candidate is
`exports/SnowForestSciFiDesk.glb`; visual approval and Studio import are pending.
The original GLB is unchanged in `source/trellis-original.glb`.

## Rebuild and check

From the repository root with Blender 4.3.2 and Python 3:

```powershell
python tools/build_snow_forest_sci_fi_desk.py
python tools/build_snow_forest_sci_fi_desk.py --check-only
```

The rebuild backs up generated files and keeps logs under
`.mapbuild/snow-forest-sci-fi-desk/<UTC timestamp>/`, authors the editable `.blend`,
exports a GLB, reimports that GLB for four textured renders, and validates it.
It never uploads or changes Studio. `tools/blender/build_snow_forest_sci_fi_desk.py`
is the authoritative editable recipe; manual changes to the generated `.blend`
will be replaced on rebuild.

## Design and delivery

- `source/reference-2.png` is the design guide because the supplied TRELLIS GLB
  depicts its raised black monitor, side consoles, keyboard, and enclosed base.
  This is an inference from the saved images, pending user visual approval.
  `source/reference-0.png` is a different desk variant retained for context.
- Provisional size: width 8.10 studs, depth 4.384, height 6.545. One Blender
  unit equals one stud. The ground pivot is at Y=0 in the final glTF.
- Final GLB axes: +Y up, +Z front. Import with Studio Scale Unit **Stud**.
- One mesh, 7,492 triangles, one shared material. The GLB embeds 1024 PNG
  color and metallic/roughness images. Separate named color, roughness, and
  metalness images are saved in `textures/`.
- `SetupDecoration.luau` is a helper if the user confirms decorative use. It
  configures the selected imported desk as anchored and non-colliding.

## Geometry decision

The original source has 282,973 triangles. A 25,467-triangle trial preserved
the broad outline but fractured the monitor frame, tabletop, and base panels.
The trial GLB and its textured view remain in `trials/` and `review/`.
The candidate is a clean rebuild of the matching reference's major forms:
wide desktop, sloped central blue display, raised dark monitor, side control
banks, keyboard, and two armored legs. Surface details are recreated with
modeled pieces and a shared atlas; no texture bake from the damaged scan is
claimed.

## Known limits

The original reference contains finer panel etching and controls than this
game-scale prototype. The rear and side construction are inferred from the
source views. Gameplay role, final dimensions, visible texture loading in
Studio, collision, map placement, and publication remain unverified.
