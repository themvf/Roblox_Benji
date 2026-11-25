# Bouncer: Avatar Setup in Studio

> Trial update (2026-11-20): Avatar Setup produced `BouncerRig.rbxm`, but movement review
> failed with severe head deformation, misplaced hair, and a neck gap. See
> `../HANDOFF.md` and `studio-review/` before repeating this procedure. The saved rig is
> diagnostic output, not approved for integration. This FBX imported at 100 times the
> intended height; the trial scaled the whole imported bundle by 0.01 before setup.

This is the skinned half of the Bouncer trial (docs/design/kits/MATCH_BODY.md). The same Tripo
model was prepared by `python tools/kit_look.py skinned Bouncer`:

- **Body:** one watertight body shell of 12,000 triangles, in an A-pose with the arms swung
  20 degrees out. It's fitted to the match body (ankle 0.3, knee 1.5, hip 2.7, waist 3.1, neck
  4.7 studs) and faces -Z.
- **Accessories:** the hair (4,028 triangles) and the shades and headset (2,256) come off as two
  rigid accessories, because Avatar Setup wants no hair or accessories in the body.
- **Files:** `Bouncer-AvatarSetup.fbx` holds all three, with the texture embedded. `Body.glb`,
  `Hair.glb` and `Headgear.glb` are the same meshes, one per file.

The rigid version (cut at the joints) stays as the comparison.

## Steps

1. **Import.** In Studio, go to Home > Import and pick `Bouncer-AvatarSetup.fbx`. In File
   General, turn **Upload To Roblox off**, then Import.
2. **Arrange it for Avatar Setup.** Rigid accessories must be bundled with the body in one Folder.
   In Explorer:
   - make a Folder named `Bouncer`;
   - inside it, put the `Body` mesh in its own Model named `Body`;
   - put `Hair` in a Model of its own, and `Headgear` in another.
3. **Open Avatar Setup.** Select the `Bouncer` folder, then go to Avatar tab > Avatar Setup.
4. **Configure Models.**
   - Preset: **Development Avatar**.
   - Type: Body for `Body`, Rigid for `Hair` and `Headgear`.
   - Under the gear icon (bottom left), turn **Reduce triangle count off**. Turn **Handle face as
     2D decal on**, because the face is plain and has no eye or mouth geometry. Use **Manually
     Align Front** only if it comes in facing away.
5. **Set Up** (bottom right). It can take several minutes.
6. **Check Body > Animations.** Play walk and jump, and look at the elbows, knees, hips and
   jacket hem from the front and the side.
7. **Test in Experience.** In a game-integrated comparison place, walk, jump, crouch and
   slide with a weapon. A blank Baseplate does not contain the game's crouch, slide, or
   weapon systems; Avatar Setup previews alone cannot verify those behaviors.
8. **Save to a file.** Right-click the finished character in Explorer, choose Save to File, and
   save it here as `BouncerRig.rbxm`. Do not use the Save button in Avatar Setup: that opens
   upload and Marketplace publishing.

## Send back

- any error Avatar Setup shows, word for word;
- a screenshot of the walk from the front and from the side;
- `BouncerRig.rbxm` (step 8). I wire it into the game as the experimental match character next
  to the rigid version.

## Known before you start

- **No facial animation.** The face is plain black, so there's nothing for it to animate.
- **Popped collar.** The rigid version's taller collar is not in this body, because Avatar Setup
  wants the neck clearly visible. The collar can come back as an accessory once the body passes.
- **Hip flap.** There's a small flap of jacket by the left hip.
- **Coil wire.** The headset's coil still sticks out sideways (it's part of the Headgear
  accessory).
- **Triangle count.** 12,000 body triangles is over the Platform preset's 10,742. That's fine
  for a Development avatar with Reduce triangle count off.
