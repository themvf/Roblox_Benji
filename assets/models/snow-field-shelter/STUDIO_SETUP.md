# Studio setup: snow field shelter

After visual approval, import `exports/SnowFieldShelter.glb` as a model using Stud units. Confirm the intended Roblox owner before upload and record the actual mesh and texture IDs in `HANDOFF.md`. The expected model has seven MeshParts. Its approximate bounds are 24.56 wide × 32.805 long × 14.231 high; the ground-level origin should place its base on the floor. Check the black fabric folds, white front truss, white door, and both side windows in Studio lighting. The GLB contains the eight PNG maps, but local renders alone cannot establish how Studio applied them.

If the chosen role remains **background decoration**, select only the imported shelter model and run `SetupDecoration.luau` in Studio's Command Bar. This anchors its seven MeshParts and disables collision, touch, and query. The file does not save or publish the place. The closed door and opaque windows are visual detail only.

For a map placement, follow `assets/environment/decor/README.md`. Preserve existing decor while adding the shelter, save the decor collection, restart the map, and confirm the model persists and does not obstruct routes. Record the destination map, decor file, import IDs, owner, texture result, physics result, and restart evidence in `HANDOFF.md`.

## Open-door variant

Import `exports/SnowFieldShelter_OpenDoor.glb` as a **separate** model. Its eight MeshParts and nine embedded PNGs differ from the closed version. Its dimensions include the swung door: approximately 24.56 × 35.617 × 14.231. Verify that the door remains outside the front wall, the aperture is clear, and the walkway and threshold appear. `SetupOpenDecoration.luau` sets all eight MeshParts to anchored non-colliding decoration. If players are intended to enter it, do not use that decor setup as evidence of a usable route; create and test the collision, interior, and map contract separately.
