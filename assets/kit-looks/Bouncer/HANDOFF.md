# Bouncer handoff

## Current truth — 2026-11-20

The Development Avatar Setup trial produced a rig, but **failed visual movement review**.
`skinned/BouncerRig.rbxm` is diagnostic output, not an accepted match character.
No game integration, Marketplace publication, commit, or phone test was performed.

Preserve the standard match-body direction in `docs/design/kits/MATCH_BODY.md` and the
acceptance test **"looks good while playing"**. The original Tripo source and rigid split
were not modified. Keep both routes for the eventual comparison.

## Observed Studio trial

- Imported `skinned/Bouncer-AvatarSetup.fbx` into a separate local Baseplate place, with
  Upload To Roblox unchecked. Import/Avatar Setup still created backing Roblox asset
  resources; this checkbox prevents a Toolbox save, not all service uploads.
- Studio imported the body at **604.9772 studs tall**, not 6.05. Uniformly scaled the imported
  bundle by 0.01 before setup; body height then measured **6.049772 studs**.
- Bundled Body, Hair, and Headgear in separate Models inside the Bouncer Folder.
- The initial preview showed the back. Rotated all imported MeshPart CFrames 180 degrees
  around Y. With **Manually align front off**, the final preview showed the face correctly.
  Manual front mode retained an unhelpful view; do not infer FBX axis correctness from the
  offline preview alone.
- Settings: Development Avatar; Body = Body; Hair/Headgear = Rigid; Reduce triangle count
  off; Handle face as 2D decal on; Improve facial caging on; optional R15 joints off.
- Setup completed and opened Check Body. It asked for Headgear.001's category, assigned
  **Face / Center**. Hair was classified Hair.
- Checked idle, walk, and a jump pose in Avatar Setup. Severe head spikes appear and change
  with the pose; hair sits across the lower face/neck; a bright open neck gap is visible.
  These defects fail the trial regardless of whether the remaining joints improve over the
  rigid split. The full source of the deformation has not been isolated.
- No blocking setup error dialog was observed. Output did log
  `Asset content representation is being generated` for several resources and
  `Multiple StyleLinks under Children may result in undefined behavior`.
  Exact output, including asset IDs, is in `skinned/studio-review/studio-output.txt`.

## Saved evidence

- `skinned/BouncerRig.rbxm`: unmodified generated `Body_autosetup` saved through Explorer's
  Save / Export > Save to File before creating a review clone.
- `skinned/studio-review/Bouncer-AvatarSetup-Trial.rbxl`: local diagnostic place containing
  the adjusted input bundle, generated result, and a separate `BouncerWalkReview` clone.
  This is not the planned gameplay comparison place.
- `idle-head-deformation.png`, `walk-front-three-quarter.png`, and
  `jump-front-three-quarter.png` in that directory: Avatar Setup preview screenshots.
- `walk-front.png` and `walk-side.png`: Studio edit-mode views of the generated rig clone,
  sampled from its generated WalkAnim (`16562332340`) at 0.35 seconds using Animator and
  StepAnimations. Fixed front/side cameras; these are animation pose screenshots, not a
  recording of player-controlled gameplay. The preview screenshots are the primary
  evidence of animation behavior. Saved places do not guarantee the transient animation
  track/time survives reopening.
- `rig-structure.json`: local deserialization verified 15 body MeshParts, 2 Accessories,
  1 Humanoid, 1 FaceControls, 15 AnimationConstraints, and 2 RigidConstraints. No Motor6D
  instances were counted. This structural result is not a skin-weight or runtime test.
- `evidence-manifest.json`: hashes of source and saved evidence. No approval is implied.

## First unverified stage / next action

Repair and repeat Studio movement review before integrating this rig into the game.

1. Isolate the generated head/face deformation from accessory placement. A controlled
   trial with **Handle face as 2D decal off** is a reasonable next experiment: the head is
   plain and has no painted eyes/mouth to infer. This is a hypothesis, not a proven fix.
   Keep this failed result and compare against it; do not overwrite it silently.
2. Inspect Hair and Headgear attachments against the generated head in rest and movement.
   Correct the attachment transforms only after checking the head's orientation and size.
3. Fix or document FBX unit handling in the repeatable prep/import path. Recheck the body
   height and front on every import rather than relying on the Blender preview.
4. Validate the generated joints and attachment locations against the match-body contract.
   Avatar Setup success does not establish the exact standard skeleton or hitbox.
5. Once idle/walk/run/jump pass, build the rigid-versus-skinned comparison with actual
   crouch, slide, aim, weapon alignment, and team readability. Then obtain user gameplay
   sign-off and device measurements with approximately ten visible characters.

Studio acceptance remains failed; gameplay and device acceptance remain unverified.
