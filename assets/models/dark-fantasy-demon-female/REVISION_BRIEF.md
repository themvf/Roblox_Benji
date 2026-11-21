# Revision brief: DarkFantasyDemonFemale v19

Review date: 2026-11-14. Overall 5/10: 6.5 as a game skin, 3 for Marketplace.
The owner approved the v18 previews, but this review found two Marketplace blockers that the
local readiness check passes without catching. Treat the package as back at **Stage 3 (Author)**
for the items below. Update HANDOFF.md and validation.json so they no longer say Stage 6 is next.

Hand this to Codex as is:

```
Revise assets/models/dark-fantasy-demon-female/ (DarkFantasyDemonFemale) to v19.
Read HANDOFF.md, MARKETPLACE_DELIVERY.md in assets/models/ninja-soldier-skins/, and this REVISION_BRIEF.md first.
The reference is source/DarkFantasyDemonFemaleReference.png. Match it, not the v18 renders.

KEEP (owner liked these)
- Classic blocky R15 body style, the black/charcoal + violet palette, the body triangle budgets.
- The face design: white irisless almond eyes, winged liner, black lips, freckles, pale lavender skin.
- The body/accessory split, watertight meshes, 1024 textures.

A. MARKETPLACE BLOCKERS (must fix)
1. Real dynamic head. v18 paints the face onto a flat texture and hides three spheres inside the skull to
   satisfy the check; that is not compliant and the face will smear when animated. Rebuild the Head with
   modeled eyes (eye geometry with eyelids that can close) and a modeled mouth with an opening and inner
   mouth, per the current Roblox Avatar Setup requirements and dynamic-head specifications (verify against
   create.roblox.com before building). The painted look stays: carry the liner, lips and freckles in the
   texture around the modeled features. Delete the hidden spheres. Stay within the 4,000-triangle head budget.
2. Template cages. The mantle and hip-tasset cages are 80-triangle placeholder boxes. Layered accessory
   cages must be built from Roblox's official template cage meshes (same topology and UVs, only vertex
   positions moved). Get the template from Roblox's official avatar project files. If it cannot be
   downloaded from this environment, STOP and ask the owner to download it into
   source/roblox-cage-templates/; do not invent cages.
3. Body cages: either author them from the same template or record in STUDIO_SETUP.md that Avatar
   Setup generates them, plus what to inspect.

B. VISUAL FIXES (match the reference)
4. Horns: replace the thin vertical ribbed coils with thick, smooth ram-style horns that curve outward and
   back, as in the reference. Broad base, tapering tip, shallow horizontal ridges only. They must read as
   horns at gameplay distance. DemonHorns stays one rigid accessory, at most 4,000 triangles.
5. Feathers: rebuild the shoulder mantle and wrist cuffs as clean layered feather blades, a few large
   overlapping tiers, not a spiky noisy mass. The silhouette should match the reference's tidy feather collar.
6. Hair: a swept dark bob with side-swept bangs and cheek-length sides, not a helmet shell.
7. Team colour: make the violet trim (collar piping, armour seams, horn ridges) a tintable region so the
   game can show Red or Blue there, e.g. a tint mask in the albedo alpha used with SurfaceAppearance
   (verify the current API). Marketplace version keeps violet. Document how the game applies the tint.

C. CHECKS THAT MUST BE HONEST
8. Extend tools/check_dark_fantasy_demon_readiness.py so it FAILS when: the head has no separate eye and
   mouth geometry, any mesh is fully enclosed inside another (hidden filler), or a cage's vertex count and
   UVs do not match the template cage. A green check must mean the blocker is actually gone.
9. Pose test: render review/posed_limbs.png with both arms raised overhead, one arm forward, knees bent
   about 60 degrees and a 30 degree torso twist, plus a crouch. Show the mantle and tassets in each pose
   and list any clipping in HANDOFF.md.
10. Re-render front/side/rear/quarter/head_closeup/ingame_scale, and add a side-by-side with the reference.

STOP after step 10 for owner visual approval. No Studio changes, uploads or publishing.
```
