# Baked maps

A baked map is `workspace.Map` saved to a file, exactly as `MapService` built it.

This exists to answer a question we kept losing days to: **why is a map built by code at
all?** It was the right call while the layout was being generated -- loops, mirrors,
parametric structure. It is the wrong call once a map is being *detailed*, where every
change is a specific visual judgement and Studio is the tool built for that.

## Why MapService does the baking

Nothing here re-implements the builder. A Lune script that emitted the bake from map data
would be a second builder that has to agree with the first, which is the drift this whole
change removes. `MapService` builds the map for real; the bake is a copy of the result;
`tools/check_bake.luau` checks the copy.

## Baking

1. **F5**, step on the **PRACTICE** pad, choose the map.
2. Let it finish building. Props load over the network, so give it a second.
3. In Explorer, select **`workspace.Map`** and press **Ctrl+C**.
4. Press **Stop**. Everything from the session is discarded -- the clipboard is not.
5. **Ctrl+V** into Workspace.
6. Right-click the pasted `Map` → **Save to File** → `assets/environment/baked/<Map>.rbxm`.
7. Delete it from Workspace and **Ctrl+S**, so the place file keeps no copy.
8. `lune run tools/check_bake.luau`

Save as `.rbxm`, not `.rbxmx`. Diffs are unreadable either way, so there is nothing to
trade for the size.

## What the gate checks

For every solid the map data describes, is there a part in the bake at that position and
size? Extra parts are expected -- the bake also carries decor, markers, lights, facade
meshes and props that were loaded at runtime, none of which the validator models. What it
catches is a **missing** solid: a wall that is in the source and not in the file, which
means the bake is stale.

Matching is by position and size within 0.1 studs, not by name: `MapService` prefixes a
mirrored pair `Red_`/`Blue_` while the validator models the unmirrored copy without a
prefix. It is a range test rather than a rounded key because Roblox stores these as 32-bit
floats -- 5.7 comes back as 5.699999809, and a bucketing scheme put those on opposite sides
of a boundary often enough to report five missing walls in a complete bake.

Orientation is not compared. Position and size catch a stale bake, which is the failure
that matters; a rotation that is wrong in the bake was wrong when the builder produced it.

## While both paths are live

Baking does not switch anything on its own. `MapService` still builds from the map module,
and the bake sits beside it until the geometry has been compared and you are satisfied.
The switch -- load the model, point the gates at it, delete the builder -- is a separate
change.

One consequence worth knowing before it bites: **`.rbxm` cannot be merged.** Once a map is
baked, one person edits it at a time. With several sessions working in this repo, that is a
real constraint rather than a theoretical one.
