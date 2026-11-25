# Studio setup: purple column

After visual approval, import `exports/PurpleColumn.glb` as a model using Stud units under the intended experience owner. Record the actual mesh and texture IDs in `HANDOFF.md`. Expect six MeshParts, about 12 studs high and 2.52 × 2.56 studs across. Confirm the base rests on the floor, the violet color and stone wear survive the import, and the capital is intact under lobby lighting. The GLB embeds color and packed metal/roughness PNG maps, but local rendering does not prove how Studio applies them.

For a **non-colliding decorative placement**, select only the imported model and run `SetupDecoration.luau` in Studio's Command Bar. It anchors its six MeshParts and disables collision, touch, and query. The helper does not save or publish the place. If the column should physically block players, add a simple invisible collider after approving its exact size and position; test the player path rather than relying on the sculpted mesh's collision.

To place it in the lobby, follow `docs/design/lobby-experience/EDITING.md`: add the approved model under the editable `Lobby.Geometry`, save `assets/environment/source/Lobby.rbxm`, run `tools/save_lobby.cmd`, restart Play, and verify the saved lobby. Preserve the existing lobby and authoring markers. Record owner, IDs, imported appearance, collision, placement, and restart evidence in `HANDOFF.md`.
