# Resume here: server rack

## Current truth

The user approved the prototype's appearance ("That looks great"). It is an
8-stud mesh-front cabinet for background decoration. Do not ask these choices
again. The final file is `exports/ServerRack.glb`, not anything in `trials/`.

Local production checks passed: 4,096 triangles, one mesh/material, PNG textures,
bottom pivot and eight-stud height. No Studio import, upload, ownership, physics,
saved placement, or published-game verification has been observed. Asking how to
import it does not prove the user imported it. Asset IDs and destination map are
unknown. This is the next boundary to resolve, not another modeling task.

## Next engineer's first steps

1. Read this file, `README.md`, and `validation.json` in this package.
2. From the repository root run `python tools/build_server_rack.py --check-only`.
3. Establish whether the user already imported it. Reuse an existing valid upload
   rather than making duplicates. Resolve the target map and game asset owner.
4. Import the final GLB with Stud units if needed. Verify texture loading and height.
5. Apply `SetupDecoration.luau` to only the selected imported rack. It sets
   Anchored=true and CanCollide/CanTouch/CanQuery=false. GLB extras alone do not
   enforce these Roblox properties.
6. Save placement using `assets/environment/decor/README.md`. Preserve all existing
   decor in the destination map's file; never replace the collection with only the
   rack. Save runtime authoring changes before stopping Play/Run.
7. Restart the map and verify appearance, persistence, and non-collision. Record
   actual mesh/texture asset IDs, owner, map name, decor file, and evidence here.

## Rebuild only when needed

`python tools/build_server_rack.py` backs up the current generated package under
`.mapbuild/server-rack/`, then authors, exports, appraises, renders, and validates.
Blender 4.3.2 and Python 3 are the tested tools. For another installation use
`--blender "absolute/path/to/blender"`. Dependencies for the rebuild are Blender's
built-in numpy and standard Python; no TRELLIS, GPU service, or npm is required.
Logs accompany the backup; `validation.json` records failure as well as success.
The command does not upload, place, commit, or publish anything.

The generator `tools/blender/build_server_rack.py` is the authoritative editable
source for this version. Manual edits to the generated `.blend` will be replaced
by the next rebuild; transfer desired edits into the generator first. Previews
must be visually reviewed after changes even when numeric validation passes.

## Do not repeat failed work

- Do not resume the browser's TRELLIS session: it is not a durable dependency.
- Dense GLB decimation damaged panels. The hosted exporter clamps its target to
  100,000; the smaller generation trial also failed visual review.
- This rack is a clean rebuild with recreated surface detail, not a successful
  bake from the dense model. It has a real mesh grille, not transparent glass.
- Preview defaults to clay; texture reviews need `--materials original`.
- The shared asset gate currently reports a pre-existing missing appraisal in
  `assets/scenery/mud-grassland`. Record separately from this rack's result.

## Transfer to another machine or engineer

Keep this entire package, the builder and wrapper, `scene_kit.py`,
`preview_scene.py`, `appraise_asset.py`, `gltf_post.py`, and `scenes.json` together
in the repository. Git commit/push or a project backup is still required for
off-machine recovery; these files are currently local work, not a cloud backup.
Do not include credentials in the handoff. Once imported, record asset IDs here.

## Studio record (fill only from observed evidence)

- Asset owner: unknown
- Mesh and texture asset IDs: unknown
- Target map and decor file: unknown
- Imported eight-stud size / textures: unverified
- Decoration physics settings: unverified
- Restart persistence / published game: unverified
