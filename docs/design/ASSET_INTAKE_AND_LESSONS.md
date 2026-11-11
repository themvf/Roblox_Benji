# Asset intake: deciding what a source asset is good for

For durable delivery and resuming with another engineer, also follow
[ASSET_DELIVERY_WORKFLOW.md](ASSET_DELIVERY_WORKFLOW.md).

Written after the Snow Fortress horizon took four attempts. Every one of them was
avoidable, and the thing that would have avoided them is a five-second check at the
start rather than a pipeline built on an assumption.

Companion to [ROBLOX_BLENDER_ASSET_PIPELINE_SPEC.md](ROBLOX_BLENDER_ASSET_PIPELINE_SPEC.md),
which covers producing an asset once you know what it is for. This covers deciding
whether it can be that thing at all.

## 1. Run the appraisal first

Before any modelling, placement or pipeline work:

```bash
blender -b -noaudio --python tools/blender/appraise_asset.py --     --source "<file>" --record assets/<kind>/<name>/appraisal.json
```

`--record` writes the measurements, the verdict and an empty `decision` field. Fill
that field in with what the asset is for. **`lune run tools/check_assets.luau` fails
until you do**, and it runs in CI, so this is not a step an agent can skip or a
reviewer has to remember. That is the whole point: the four rounds below happened
because the check was advice, not a gate.

It measures triangles, relief ratio, open boundary edges, one-sidedness and UVs,
and says what the asset is fit for. On the glacier scan it prints, immediately:

```
triangles  712,818  (Roblox caps a mesh at 10,000)
           must lose 98.6% to fit one mesh  <-- silhouette will not survive
relief     0.119  (thinnest / longest span)  <-- reads FLAT at any distance
overhangs  100.0% of faces point downward  <-- one-sided: a height field
verdict
  A height field, not a model: single-valued from above, so it has no
    sides and no underside. It was authored to be looked down on.
  NOT a horizon.
```

That is the whole four-round conclusion, before a line of pipeline code.

## 2. The question to ask out loud

**What is this asset _of_, and from what viewpoint was it authored?**

It is not the same question as "what do I want to use it for", and the mismatch
between the two is what cost the time here. The brief said "use this terrain as the
terrain for the map ... a nice scenic view". The asset was a top-down scan of a flat
ice plain. Both are reasonable; they are not compatible, and nothing downstream can
reconcile them.

Ask the person supplying the asset, or measure it. Do not infer it from the filename.

## 3. What each measurement decides

| Measure | Threshold | What it rules out |
| --- | --- | --- |
| Triangles | 10,000 per mesh | Above it you must decimate or tile. Past ~90% reduction the silhouette is gone, and silhouette is most of what reads at distance. |
| Relief ratio | ~0.20 | Below it, a form reads as a flat plate from any distance. No placement, scale or lighting fixes this. |
| One-sided | >98% of faces one way | A height field. It has no sides and no underside, so from below you see through it, and it has a cliff at every edge. |
| Open boundary | any, on a height field | Those edges are visible cliffs. Measured on the glacier: 38-53% of relief on average, up to 100%. No rotation hides them. |
| UV / bake direction | — | An orthographic top-down bake smears when the asset is seen from the side. |

## 4. Where each kind of asset belongs

| Asset is | Use it as | Tool |
| --- | --- | --- |
| Closed, has depth, reads from any angle | in-game mesh prop | `tools/blender/scene_kit.py` |
| A horizon, of any kind | skybox, rendered offline | `tools/blender/make_sky_range.py` |
| Ground the player stands on | Roblox Terrain data in the map | `Terrain` in the map module |
| A top-down scan | viewed from above, or as a source inside a skybox render | — |

The single most useful rule: **nothing distant should be geometry.** A skybox is
rendered offline, so it has no triangle or texture budget, and by the time Roblox
sees it, it is six flat images. It cannot be mis-oriented, cannot have seams, needs
no LOD and costs no parts.

## 5. What was actually tried, and why each failed

1. **Scan as mesh geometry, ring of plates near the arena.** Decimated 712,818 to
   16,873 triangles, tiled to clear the mesh cap, placed 1500 studs out. In game:
   enormous flat slabs beside the playfield. The plate's inner edge sat 55 studs
   past the barrier with peaks at 55 degrees of elevation.
2. **Vertical exaggeration and a better ring.** Relief pushed 0.119 to 0.476, ring
   moved to 2200 with eight plates and a snow plain. Better in a render; still a
   smeared top-down bake seen side-on, with cliff edges. `Solidify`, to close the
   open underside, shredded the scan's non-manifold geometry outright.
3. **Roblox terrain `FillBall`.** Native, cheap, and what Carrier, Forest and Swamp
   already use. But it fills *balls*: smooth bald domes with no detail. Correct
   mechanism, no aesthetic.
4. **Generated silhouette rendered to a skybox.** Works, and is what shipped.

Attempts 1 and 2 were the same mistake twice. Attempt 3 was right to look for the
existing pattern in the codebase and wrong to assume it would carry a look it was
never asked to carry.

## 6. Process lessons

- **Check the codebase for an existing solution before building one.** Three maps
  already declared `Terrain.Mountains`. That check belonged before the pipeline, not
  after two rounds of it.
- **A render in isolation is not evidence.** Blender's importer silently converts
  axes on the way in, so a mesh exported with its height on the wrong axis looked
  correct in every preview and would have stood on its side in game. Verify against
  the file, not the viewer: read the GLB's `POSITION` accessor min/max directly.
- **One sample is not a test.** A single ray to the enemy spawn said the lane was
  blocked. Testing all six spawn points across 18 firing positions found 8 open
  lanes. Sample the volume, not the centre.
- **Ask what a thing is before building for it.** The cheapest step in this whole
  sequence was the one never taken.

## 7. Intake checklist

- [ ] Run `appraise_asset.py --record`. Read the numbers, not just the verdict.
- [ ] Fill in `decision`. `check_assets` fails until it is there.
- [ ] State what the asset is _of_ and the viewpoint it was authored for.
- [ ] State where it will be seen from in game, and how far away.
- [ ] Check whether an existing map or service already solves this.
- [ ] Pick the destination from the table in section 4 before any pipeline work.
- [ ] For anything distant, default to a skybox and justify any alternative.

## 8. Generated meshes: the shard soup and the copied-in junk

Added after the blue tube. An image-to-3D mesh (TRELLIS and similar) arrives as tens of
thousands of disconnected shards: 9,000 to 27,000 pieces on every asset we have, none
with a main body above 3% of its faces. That is the generator's normal output, so a
piece count cannot be a gate, and decimating to 9,000 triangles hides it anyway.

What does go wrong is **content**. The generator copies whatever surrounds the object in
the reference photo, and cannot make transparency. The tube arrived with a floor cable
tangle, a flat plate, a bottle, a second canister, loose wires, and glass as an opaque
pale slab. None of it showed in the triangle count or relief ratio.

- **Brief the generator.** Isolated object only: no floor, cables, ground plane, loose
  props or transparent materials. This prevents most of it for free.
- **Look at `views.png`.** `appraise_asset.py --record` renders front, side and top next
  to `appraisal.json`, and `check_assets` fails a package dated 2026-10-05 or later
  without it. Open it before building. One look found everything above.
- **Cull by rule, not by guess.** Read positions off the views and write them as `cull`
  rules in `scenes.json` (op_cull in `scene_kit.py`), so the removal is reviewable data.
- **Do not trust a metric for this.** A "floor clutter" percentage was built and
  discarded: it flagged both broken walls (their rubble apron is intended) and the
  helicopter, and gave the junk-ridden tube 3%, because the cables loop inside the body's
  footprint. No number told cables from rubble; a person looking did.
- **Glass is a modelling decision.** Replace it with something that reads, e.g. a column
  of colour painted into free atlas space (`prepare_bluetube.py`), or a separate
  transparent part added in Studio.

Checklist additions: [ ] generator brief excluded floor/cables/props/transparency;
[ ] `views.png` opened and the junk, if any, listed; [ ] `cull` rules written and the
result re-viewed.
