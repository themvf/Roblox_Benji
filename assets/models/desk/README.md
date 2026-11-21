# Futuristic office desk: clean-rebuild prototype

**Continuing this work? Read [HANDOFF.md](HANDOFF.md) first.**

Status: user-approved look (2026-09-27). Studio import, physics and placement unverified.

## Sources

- `source/design-reference.png`: Midjourney side view, the authoritative design.
  Copied unchanged from `Desks/degennfts_Futuristic_office_desk..._3.png`.
- `source/trellis-original.glb`: TRELLIS output, copied unchanged from
  `Desks/sample_2026-09-27T174041.800.glb`. Reference only.
- `source/trellis-reference-appraisal.json`: its appraisal and why it was rejected.

## Deliverables

- `exports/Desk.glb`: 5,828 triangles, one mesh, one material, about 0.24 MB.
- Bounds (glTF/Roblox): X -7..7 (length 14), Y 0..3.0, Z about -1.94..1.94.
  Bottom-centre pivot. Front (pod display, leg door) faces +Z. Work surface at
  about 2.95 studs; the control knob reaches 3.0.
- Embedded 1024 PNG colour and packed metallic/roughness maps; separate
  `textures/Desk_Color.png`, `Desk_Roughness.png`, `Desk_Metalness.png`.
- `source/Desk.blend`: editable parts in SOURCE (hidden), joined mesh in EXPORT.
  The generator `tools/blender/build_desk.py` is authoritative; blend edits are
  overwritten by the next rebuild.
- `review/prototype-{front,front-quarter,rear-quarter,end}.png`: textured renders
  of the final GLB at true scale.
- `SetupDecoration.luau`: Studio Command Bar helper for the selected desk.

## Rebuild

```text
python tools/build_desk.py              # backup, author, export, appraise, render, validate
python tools/build_desk.py --check-only # validate current files only
```

Backups and per-stage logs go to `.mapbuild/desk/<timestamp>/`. The wrapper keeps
the human-written appraisal `decision` across re-records. It never uploads.

## Experiment history (2026-09-27)

- TRELLIS GLB: 289,280 triangles, two 2048 WebP textures (not Roblox-readable).
  Textured renders `review/source-a..d.png`. Silhouette is close to the reference,
  but it adds a second pod and a sunken screen well that the reference lacks, and
  its surfaces are lumpy.
- One-mesh decimation trial (`trials/decimate_trial.py`, collapse to 9,000):
  `review/trellis-decimate-9000.png` shows shredded, faceted surfaces. Rejected.
  Tiling (8+ meshes) was not pursued for a single hand-scale prop.
- Clean rebuild: filleted side profiles traced from the reference, extruded and
  bevelled, with modelled seams and an atlas for the display and tablet glass.

## Known limitations

- Depth (about 3.9 studs) and the rear/end design are inferred; the reference is
  a single side view. The rear mirrors the leg door and seams but has no display.
- No collision proxy. Collision role is an open decision (see HANDOFF.md).
- The work surface is square-cornered in plan; the reference does not show it.
