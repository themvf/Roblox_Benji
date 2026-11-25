# Simple sci-fi desk prototype

Read [HANDOFF.md](HANDOFF.md) before continuing. The local delivery candidate is
`exports/SimpleSciFiDesk.glb`. Visual approval and Studio import remain separate
stages. The supplied GLB is preserved unchanged in `source/trellis-original.glb`.

## Rebuild and check

From the repository root with Blender 4.3.2 and Python 3:

```powershell
python tools/build_simple_sci_fi_desk.py
python tools/build_simple_sci_fi_desk.py --check-only
```

The first command backs up generated files and logs under
`.mapbuild/simple-sci-fi-desk/<UTC timestamp>/`, creates editable Blender source,
exports GLB, reimports the written GLB for four textured views, and validates
it. It does not upload or edit Studio. `tools/blender/build_simple_sci_fi_desk.py`
is the authoritative recipe; manual `.blend` changes will be replaced.

## Design and delivery

- `source/reference-0.png` is the likely design source: the supplied mesh
  matches its wide tabletop, four dark screens, and open space between legs.
  This visual match is an inference pending user approval. `reference-2.png`
  is a different desk variant retained for context.
- Provisional size: width 9.2, height 5.425, depth 4.589 studs. Blender units
  are authored as studs. The final glTF is Y up, front +Z, ground pivot Y=0.
  Import with Studio Scale Unit **Stud**.
- One mesh, 4,268 triangles, one shared material, two embedded 1024 PNG maps.
  The three named atlas channels are also saved under `textures/`.
- `SetupDecoration.luau` configures the selected Studio import as anchored and
  non-colliding if the user approves a decoration role. GLB does not set Roblox
  physics properties.

## Geometry decision

The supplied source has 299,417 triangles. A 26,947-triangle textured trial
kept the shape but broke its long tabletop and monitor edges. The trial GLB
and comparison views remain in `trials/` and `review/`. The candidate is a
clean rebuild with two separated legs, broad top, four-screen rear console,
sloped lower panel, and recreated accents. No texture transfer from the
damaged scan is claimed.

## Known limits

The reference has more fine panel etching than the game-scale prototype.
The rear and side details are inferred from source views. User approval,
Studio texture loading, physics, asset ownership, and map placement remain
unverified.
