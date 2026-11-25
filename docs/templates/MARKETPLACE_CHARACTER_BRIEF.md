# Marketplace character brief (Midjourney -> TRELLIS -> Codex)

Use this for every new character that should become both a Roblox Marketplace bundle
and a selectable in-match skin. Part 1 is the checklist for making the input image;
part 2 is the brief to hand Codex once TRELLIS has produced a GLB. Fill in every `<...>`.

## Part 1: making a TRELLIS-ready image

TRELLIS rebuilds one image into one static mesh. Everything in the picture becomes
geometry, and the lighting becomes texture. Before uploading, check the image has:

- **One figure, full body, head to feet.** No turnaround sheets, no portraits, no crops.
- **A T-pose** with a visible gap between the arms and torso and between the legs.
- **A plain light grey background.** Dark characters on dark backgrounds get cut apart.
- **Flat, even studio lighting.** Dramatic light, gloss and reflections bake in permanently.
- **Solid, chunky details.** Fur, hair, feathers and claws sculpted as solid shapes.
  Hems end at the hips; long coats and robes fuse to the legs.
- **Nothing floating.** Energy, particles, ribbons and debris become ability VFX later;
  glow belongs painted into the surface (seams, veins, eyes).
- **No held objects, weapons, pedestals, brand logos, text or real-person likeness.**

Prompt pattern that worked: start with `3D render of a stylized Roblox character, single
character, full body, front view, centered`, end with `standing in a T-pose with arms fully
extended horizontally to the sides, clear gap between arms and torso, legs apart, stylized
proportions taller than a classic Roblox avatar, smooth simple shapes, matte finish,
hand-painted game textures, soft even studio lighting, plain light grey background`, and use
`--ar 2:3 --style raw`. Drop `Roblox UGC style` if results turn into a blocky mannequin.
Use an approved character as `--oref` (low `--ow`) to keep the roster consistent.

In TRELLIS, keep the default decimation target and a 2048 texture: the download is the
reference for a rebuild, not the in-game mesh. Save it with the input image:

- `assets/models/<name>/source/<Name>Source.glb`
- `assets/models/<name>/source/<Name>Reference.png`

## Part 2: the Codex brief

```
New Marketplace character: <Name>. Folder: assets/models/<name>/.

INPUTS
- source/<Name>Source.glb: TRELLIS image-to-3D output. Static, ~300k triangles, one fused mesh, 2048 texture, no skeleton. Expect fragments and baked lighting.
- source/<Name>Reference.png: the Midjourney image that was fed to TRELLIS. This is the approved design.
- Goal: ONE design delivered twice: (a) a Roblox Marketplace character bundle, (b) a selectable in-match skin in this game, using the same uploaded assets.

READ FIRST, BEFORE PICKING A METHOD
- docs/design/ASSET_DELIVERY_WORKFLOW.md (stage process; start a HANDOFF.md in this folder and keep it current)
- assets/models/ninja-soldier-skins/HANDOFF.md and MARKETPLACE_DELIVERY.md (what failed and the target package)
- assets/models/ninja-soldier-skins/source/roblox-avatar-template/ (official Stylized Male reference for body construction and scale)

HARD RULES
- Never rig, segment or upload the TRELLIS mesh itself. Rigid R15 segmentation and skinning of raw image-to-3D scans tore at the joints last time. The scan is a reference for shape and texture only.
- Build a clean, watertight, contiguous humanoid body in A- or T-pose with 15 named R15 regions, using the official template for scale and proportions. Then bake the scan's colour (and normal/roughness where useful) onto it.
- Body budget: 10,742 triangles total. Head 4,000, torso 1,750, each arm 1,248, each leg 1,248. Check these against the current Roblox character-body specifications page before finalizing.
- The head must be a dynamic head with real, modeled eyes (with eyelids that can close) and a modeled mouth with an opening and inner mouth, per the current Avatar Setup requirements. A face painted on a flat texture is not compliant, and hidden filler geometry inside the skull is not a substitute. Any face covering (hood, helmet, mask, sunglasses) becomes a separate accessory over a compliant head; it is never part of the head itself.
- Anything that won't fit the body budget (hoods, mantles, horns, collars, chains, talismans, antennas) is a rigid or layered accessory: one watertight mesh each, at most 4,000 triangles, and layered accessories also get R15 weighting and inner/outer cages.
- Cages come from Roblox's official template cage meshes (same topology and UVs, only vertex positions moved). Never invent placeholder cages. If the template can't be downloaded, STOP and ask me to fetch it.
- Leave a tintable region (trim, seams, accents) for team colour, so the game can show Red or Blue on the skin. Document how the game applies the tint.
- Checks must fail on the real problem: no modeled eyes/mouth, meshes hidden inside other meshes, cages that don't match the template. A green check that a cosmetic workaround satisfies is worse than a red one.
- Textures baked to 1024 max, named consistently. No baked lighting or reflections, no brand logos, no text.
- Keep the design's silhouette and identity: <must-keep features, e.g. hood, glowing teal eyes, shoulder mantle, talismans>. Anything rebuilt simpler gets noted in HANDOFF.md.
- Weapons and ability effects are NOT part of this package.

STAGES. Stop and report at each marked STOP.
1. Intake: hash the inputs into validation.json. Run
   blender -b -noaudio --python tools/blender/appraise_asset.py -- --source "assets/models/<name>/source/<Name>Source.glb" --record assets/models/<name>/appraisal.json
   then fill in decision: "Marketplace character bundle + matching game skin; TRELLIS scan used as shape/texture reference only."
2. Plan: write the body/accessory split (which features go where, triangle estimate per region and per accessory) into HANDOFF.md.
3. Author: clean body plus accessories in an editable .blend, texture transfer, exports in exports/.
4. Local checks: a reproducible script (model it on tools/check_ninja_marketplace_readiness.py) that reports triangles per region and per accessory against budget, watertightness, UVs, texture sizes, R15 naming, orientation (Roblox forward is -Z) and source hashes. Write marketplace_readiness.json.
5. Previews: front, side, rear and quarter, a side-by-side with the reference image, and a real pose test into review/: both arms raised overhead, one arm forward, knees bent about 60 degrees, a 30 degree torso twist, and a crouch, with every accessory on. Joints must stay closed with no floating pieces; list any clipping in HANDOFF.md.
   STOP: visual approval is mine.
6. Studio handoff: write STUDIO_SETUP.md with exact import settings and the Avatar Setup steps (Platform Avatar preset), plus what to inspect: generated dynamic head and face animation, cages, accessory fit, idle/run/jump/swim/emotes, and any validation errors.
   STOP: do not modify any Studio place, upload assets or publish. I confirm the place, the creator account or group, the catalog titles and the pricing, and I approve any paid upload.
7. Game integration (only after the asset IDs exist): wire the uploaded body and accessories into the Customize -> Character selector in place of block-part prototypes. Run stylua, selene, rojo build and the lune gates listed in CLAUDE.md.

DONE MEANS: an approved preview set, a passing local readiness report, and a Studio setup guide ready for me. The handoff marks every stage verified or pending; never claim Marketplace approval from local checks.
```

## Before the upload stage

- Marketplace publishing needs a verified account, charges upload fees and goes through
  Roblox review. Those steps stay with the owner, never Codex.
- Confirm you have the rights to commercially use the Midjourney image and TRELLIS output,
  and record that in the package's HANDOFF.md.
