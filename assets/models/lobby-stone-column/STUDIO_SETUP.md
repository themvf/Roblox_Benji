# Studio setup: lobby stone column

After visual approval, import `exports/LobbyStoneColumn.glb` as a model using Stud units under the intended experience owner. Record actual mesh and texture IDs in `HANDOFF.md`. Expect six MeshParts, about 12 studs high and 2.38 × 2.40 studs across. Check that the base rests on the floor, the blue-gray stone wear survives import, and the damaged capital reads under lobby lighting. The GLB embeds color and packed metal/roughness PNGs, but a local render cannot establish how Studio applies them.

For a non-colliding decorative placement, select only the imported model and run `SetupDecoration.luau` in Studio's Command Bar. It anchors all six MeshParts and disables collision, touch, and query; it does not save or publish the place. If the column should block players, use a simple separate invisible collider after approving exact scale and position, then test the player path.

For lobby placement, follow `docs/design/lobby-experience/EDITING.md`: add the approved model under the editable `Lobby.Geometry`, save `assets/environment/source/Lobby.rbxm`, run `tools/save_lobby.cmd`, restart Play, and verify the saved lobby. Record owner, IDs, appearance, collision, placement, and restart evidence in `HANDOFF.md`.
