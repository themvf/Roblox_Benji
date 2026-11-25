# Studio setup: snow utility vehicle

After visual approval, import `exports/SnowUtilityVehicle.glb` as a model using Stud units. Confirm the intended Roblox owner before upload and record the resulting mesh and texture IDs in `HANDOFF.md`. Expect nine MeshParts, about 8.45 × 14.14 × 7 studs, with the tires at ground level. Check the white body, dark glazing, black tire tread, orange wheel trim, and front/rear orientation under the intended map lighting. The GLB embeds color and packed metal/roughness PNGs, but Studio's final material appearance must be observed there.

If the approved use is **stationary background decoration**, select only the imported model and run `SetupDecoration.luau` in Studio's Command Bar. It anchors the nine MeshParts and disables collision, touch, and query. The helper does not save or publish the place. Do not use it as a vehicle chassis or as gameplay cover.

For placement, follow `assets/environment/decor/README.md`. Add the model without replacing existing decor, save the collection, restart the map, and verify persistence and non-collision. For a drivable vehicle or reliable cover, create a separate gameplay design and rig/collision setup before placement. Record the owner, asset IDs, actual dimensions, material result, physics result, target map, decor file, and restart evidence in `HANDOFF.md`.
