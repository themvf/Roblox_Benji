# Studio setup: snowmobile

After visual approval, import `exports/Snowmobile.glb` as a model using Stud units. Confirm the Roblox asset owner before upload and record actual mesh and texture IDs in `HANDOFF.md`. Expect nine MeshParts, approximately 5.49 × 13.80 × 5.5 studs, with the skis and track at ground level. Inspect the blue-black windshield, white body panels, seat, black skis, and rear track under the target map's lighting. The GLB embeds color and packed metal/roughness PNG maps; verify how Studio applies them rather than assuming the local render predicts the final material.

For approved **stationary background decoration**, select only the imported snowmobile and run `SetupDecoration.luau` in Studio's Command Bar. It anchors all nine MeshParts and disables collision, touch, and query. The helper does not save or publish the place. Do not apply it if the model is intended as gameplay cover or a drivable snowmobile.

For map placement, follow `assets/environment/decor/README.md`. Preserve existing decor, save the updated collection, restart the map, and verify persistence and physics. A rideable version requires a separate Roblox chassis, seat, controls, steering ski, animated or simulated track, and gameplay collision contract. Record observed owner, IDs, size, textures, physics, map file, and restart evidence in `HANDOFF.md`.
