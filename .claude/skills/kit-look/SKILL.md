---
name: kit-look
description: Make a kit's character look to the BedWars-kit minimum bar (bar -> concept sheet the user approves -> one crop per armour piece -> Tripo GLB per piece -> intake -> assembled R15 review sheet beside the benchmarks). Use whenever a kit, hero or character skin needs its appearance made or improved, e.g. "make the Black Knight look like a BedWars kit" or "design the look for the Pulsar kit". Not for props, vehicles or guns (asset-from-prompt), and not for kit abilities (kit-from-prompt).
---

# A kit's look

**The bar is BedWars kits, as a minimum** (the user, 2026-11-17). The screenshots and the four
things every one of them does are in
[docs/design/kits/look-benchmarks/STYLE_BAR.md](../../../docs/design/kits/look-benchmarks/STYLE_BAR.md):
something breaks the outline, one glow colour, painted texture, exaggerated proportions.

Everything runs through `python tools/kit_look.py` and lives in `assets/kit-looks/<Kit>/`.

## Why it is shaped like this

What went wrong on the first knight, so it is not repeated:

- Box armour built from shapes was the first attempt, and nowhere near the bar. Do not build
  armour from primitives.
- One generated statue of the whole character tears at the joints when it animates
  (ninja-soldier-skins). Each piece rides **one** R15 body part instead.
- A text prompt per piece drifts in style. Every piece is cut from **one approved concept**.
- Design changes made in 3D cost a rebuild and a render each. Change the concept picture instead.

## The run

1. `kit_look.py plan <Kit> [--pieces ...]` makes the look. Slots: helmet, chest, waist,
   pauldron, gauntlet, fist, thigh, greave, boot, back. Mirrored slots are made once, as the left.
   Each slot has a box on the blocky R15 body and a triangle allowance; the whole character is
   20,000.
2. `kit_look.py bar <Kit> --outline --glow --texture --proportions --glow-plates --team`: how
   this kit meets each line. Decide these yourself from the kit's fantasy; concept refuses while
   one is empty. `--glow-plates` names what must really glow in game ("eyes", "chest rune", or
   "none"): paint cannot glow in Roblox, so those become Neon plates, and the knight found that
   out only after its eyes were painted. `--team` says how a red or blue player reads (a trim,
   the glow); the knight was finished and uploaded with none.
3. `kit_look.py concept <Kit>` prints a Midjourney prompt for a turnaround sheet built from the
   bar. The user makes it in **Midjourney** (their tool), attaching any earlier picture of the
   character as the image reference, and sends the picture: `concept <Kit> --image <file>`.
   A single front view is acceptable (the Black Knight's was); a turnaround helps Tripo with backs.
4. **The one check-in.** Show the concept beside two benchmarks. `approve <Kit> --said "..."`
   with the user's own words about the picture; "continue" is refused. Iterate the picture,
   not the model, until they approve. A piece made before approval rarely matches:
   `reset <Kit> <piece>` sets it aside.
5. **Split the pieces by what the concept shows.** Draw boxes on the concept and look at them
   before cutting anything.
   - Shown large, whole and unobstructed: `crop <Kit> <piece> x0 y0 x1 y1`. Usually only the
     helmet and shoulder plate qualify. A crop under 240 px on its short side is refused (the
     knight's fist, shin and boot were ~150), and a piece cut on all four sides, like a chest in
     the middle of the body, comes back from Tripo as a flat slab: draw torsos instead.
   - Small, hidden or not shown (usually fists, shins, boots, belt, cape): `draw <Kit> <piece>`.
     It writes the piece's Midjourney prompt to `DRAW.md`: that piece alone, empty, in the bar's
     style, with the concept attached as the image reference. When the picture comes back,
     `draw <Kit> <piece> --image <file>` makes it the piece's Tripo input. A fist is filed with
   `--hand left|right`, said after looking: the prompt asks for a left hand and Midjourney drew
   the knight's as a right one, which put the hands on the wrong arms.
   A look that is clothing, not plate armour (the Bouncer: leather jacket, trousers, gloves),
   sets each piece's `subject` in look.json (a jacket sleeve, not a shoulder plate) and a
   look-level `drawStyle` (its material line); the slot names stay the same. A head with hair
   and glasses is the `helmet` slot drawn as a whole featureless head: it replaces the Head.
   `TRIPO.md` is the user's checklist: each piece's input, face count and what it covers.
6. Send the user `DRAW.md` for the drawings (Midjourney has no API here). Then make the pieces:
   - **With the Tripo CLI** (`npm install -g tripo-cli`; the key is the user's `TRIPO_API` Windows
     variable, read by the tool and never printed): `kit_look.py make <Kit>` prints the credit
     cost; `make <Kit> --confirm` runs every ready piece on P2 at its face count (plain colour,
     no PBR shine), six at a time, and files each through `intake`. The helmet, chest and shoulder plate run on
     P2 (120 credits); every other piece on v3.1 (40), which left stray flaps on the knight's helmet
     but made a shin guard hard to tell from P2's at game size. `--model` puts every piece on one
     model. Ten pieces cost about 640 credits this way instead of 1,200. Check the balance first.
   - **Without it**, the user runs each input through Tripo's site (image to 3D, export GLB,
     Retopo Triangle at the face count) and sends the files back in any order.
   When drawings come back, read each one before filing it: the right piece, alone and empty,
   upright, matching the concept's glow. Pick the best of duplicates; keep rejects in
   `drawings-unused/`. Midjourney draws boots calf-high however they are asked for: accept it
   and intake the boot with `--trim 0.4`, which cuts it at the ankle (the shin piece covers the
   cut). A cape must have no hood and stop at the back of the knees, or the legs walk through it.
   Midjourney draws it as a round cloak seen from behind: review keeps the back half and hangs it
   behind the chest piece, and its intake takes `--turn 90` (drawn from behind, unlike the rest).
7. `intake <Kit> <piece> <file.glb>` decodes it, takes the shine off (Tripo exports near-mirror
   metal), and checks triangles. Tripo faces +X, so pieces are turned -90° by default; if the
   review shows a piece facing the wrong way, re-run intake with `--turn`. Forearm, thigh and
   shin pieces are stood upright by their long axis and fitted by width so they wrap the limb;
   one that lands upside down takes `--flip`. The fist is stood upright too (cuff up, knuckles
   down); draw it in the armour's plate colour, because a chrome or silver drawing comes out a dark
   grey lump once the shine is taken off (the knight's first fist). Mirrored pieces assume the
   drawing is the left; a fist drawn as a right hand ends up on the wrong arms (thumb outside):
   `draw --hand right` sets the piece's `"handed": "right"`. A hanging fist shows the steel back of the
   hand outward and its curled fingers toward the leg. A shoulder plate is an open
   shell, so its slot adds a dark `sleeve` that fills the hidden upper arm; check `hands.png`, the
   close-up of fists, forearms and sleeve, for both. The chest slot's `fillWidth` stretches the
   breastplate to the shoulders; without it the knight showed sky between chest and arms.
   A texture cannot glow in Roblox: painted lights that must glow (eyes, runes) go in the look's
   `glows` list (part, centre and size in Blender studs, colour), found by raycasting the fitted
   piece for those texels. Review renders them emissive; KitLookService makes them Neon parts.
   At the first review, pick the **reference**: the piece whose steel already looks most like the
   concept (`reference <Kit> pauldron` on the knight). Every piece is exported matte, so steel
   only reads as steel through its paint, and pieces drift apart unless they are matched to one.
   **Every cropped piece gets finished** before the user sees the sheet; review lists the ones
   that are not. A crop carries the concept's painted lighting: the knight's helmet came out as
   flat copper wood although the concept prompt asks for even lighting. A drawn piece that
   reads as wood or matte beside the others gets the same. `finish <Kit> <piece> --scratches`
   (`--like` defaults to the reference) is a Blender pass (tools/blender/finish_piece.py) that recolours it in the
   --like piece's measured steel palette, lights its real 3D edges, bakes glow into its crevices
   (the knight's visor slits), lays that piece's scratches over the steel and darkens the paint
   under its glow plates. The user chose it over the 2D `retint`, whose seams could only follow
   painted gaps. Its crevice glow defaults to the knight's orange: pass `--glow` (the Bouncer's
   leather took `--glow "#14161C"`, plain dark creases) or a jacket comes out looking like lava.
   A piece that is only one side of a larger drawing (the Bouncer's shoulder, cut from a jacket
   drawing with the body side painted out) came back from Tripo as a solid puffy sleeve; fit it
   `upright` like a limb, not as an open shell.
   A vest or jacket that stops short of the belt takes the chest slot's `fillHeight` (studs, the
   downward twin of `fillWidth`); widen the belt to match with the waist slot's `fillWidth`. Tripo's original is kept beside it; about a minute, no credits.
   Run `review` after
   each batch, not only at the end.
8. `review <Kit>` assembles every filed piece on the R15 body (missing slots show bare body;
   a piece that covers a body part hides it, as BedWars kits replace the limb)
   and renders front, quarter, side, back, head, hands close-up, walking pose and a kit-screen
   backdrop, on one sheet with the concept and two benchmarks. It also shoots rays through the
   shoulder-to-waist band from front and back and marks every hole in red on those renders:
   sky between chest and arms was the knight's longest fix, and the sheet never showed it,
   Studio did. `verdict --looks good` refuses while there are gaps, unless `--gaps-ok "<the
   user's reason>"`. Close them with the chest's `fillWidth`, the shoulder's `sleeve` and slot
   centres, not a new Tripo run. Read the sheet yourself first: wrong facing,
   floating or buried pieces, a piece that leaves its limb in the pose, a style that does not
   match the concept, the hands close-up (thumbs forward, steel outward). Fix what you can
   (`--turn`, a re-crop), then show the user.

## Clothing: one whole-body model, not pieces

Pieces suit plate armour, which really is separate plates. A look that is one outfit (the
Bouncer's leather jacket and trousers) made from nine pictures and nine Tripo runs came out as
"a lot of random pieces put together" (the user, 2026-11-19): every piece had its own lighting,
grain and wear, and reused tubes read as stovepipes. For clothing, make the whole character once:

1. The user draws the whole character in Midjourney in a symmetrical A-pose, arms and legs
   clear of the body, concept attached (`WHOLE.md` in the look's folder holds the prompt).
2. `whole <Kit> --image <file>`, then `whole <Kit> --make --confirm` (P2, one run at 16,000
   faces), or `--model-file <glb>` for a model made on Tripo's site.
3. `whole <Kit> --grid` renders a flat front view with a measuring grid; read the joints off it
   and `whole <Kit> --marks '{...}'` cuts the model (tools/blender/split_whole_body.py) at neck,
   waist, hips, shoulders, elbows, wrists, knees and ankles, swings the arms down, and maps each
   part onto its R15 joint heights so parts meet at the cuts and turn about the game's pivots.
   The old pieces are kept in look.json `setAside`. Then `review` as usual.
   Arms that hang against the body need `armInner` (the jacket's side stays torso), gloves beside
   the thighs `legOuter`, and `handLength` stops the hand zone running on down into the boots
   (the Bouncer's first cut swung a scrap of boot with each arm). Look at the walking pose.
   `whole <Kit> --unlight '[boxes]'` takes the picture's coloured light out of the texture:
   Tripo painted the Bouncer's magenta rim light down his sides in the glasses' colour. Boxes
   (grid frame, front only) mark what really glows; every other glow-coloured pixel becomes
   leather. It also cuts the texture to 1024: at Tripo's 4096 each part carried a 14 MB copy.
   `whole <Kit> --detail '[x0, y0, x1, y1]'` (after `--unlight`; both may go in one call) bakes
   worn cream edges, darker creases and leather grain over the model's own paint. The grain is
   that patch of the user's picture, projected from all six sides, because Tripo saw only the
   front: the Bouncer's back was bare dark leather and his boots and gloves smooth. The head
   and the glow faces are put back untouched (edges put bronze tips on every spike of hair).
   finish_piece.py colours are 0-1: 0-255 baked the first try white.
   After the second audit (2026-11-19) the cut also takes, in `--marks`: `overlap` (each child
   part carries a band of its parent past the cut, tucked under its surface: the walking pose
   tore open at hip, knee and hem without it), `remove` (a zip fin Tripo stood off the chest),
   `collar` (stretch a low collar ring into the concept's popped collar), `handScale`
   (oversized fists), `decimate` (the hair, only after welding; 8,900 to 4,000 triangles held
   up in the close-up). Lids on the cuts were tried and are off: a lid stretched ankle to knee
   showed through as a black bar. Glows take `turn` (slats round a curved visor) and
   `color: "team"` with `neon: false` for a team band: KitLookService paints it the player's
   Palette.World colour and follows their Team attribute. Fit a band as a ring of plates
   raycast onto the sleeve; a box stuck out like a shelf. The procedural stitch pass
   (finish_piece.py `stitch`) hatched whole patches, not seams: it is off.
4. Route 2, alongside: the same model through Studio's Avatar Setup (Avatar tab, Development
   preset), which skins it so it bends at the joints instead of being cut. That is a hands-on
   Studio step, and the game does not yet use a skinned look: KitLookService welds rigid pieces.

## Skinned looks: one command, audit first

The user wants as little human work as possible (2026-11-20). One picture goes to an audited
Avatar Setup body with no stops:

    python tools/kit_look.py character <Name> --image <picture>

It runs:
1. a widened canvas;
2. a FLUX.1 Kontext T-pose edit in flat neutral light, three seeds, the best picked from its
   silhouette (nothing touching the edges, arms spread, symmetric);
3. TRELLIS.2;
4. joints measured off the mesh (`tools/blender/measure_joints.py`, drawn on `joints-front.png`);
5. `prepare_avatar_setup.py`;
6. the audit;
7. STUDIO.md.

Every stage keeps its output, so after a GPU-quota stop the same command resumes. The audit now
covers movement too: the pose test with a rifle the size of the game's AssaultRifle in the right
hand, and the Weapons Kit's shoulder camera (2.25 right, 2.25 up, 10.5 back, FOV 70) with the
crosshair drawn. The back three-quarter view leads the views sheet.

**The FBX is written by `tools/blender/write_fbx.py`** from the GLBs: 0.01 scale, so the numbers are
studs, and the mesh turned to face +Z under the standard axis declaration. It then reads the file back
the way a plain importer does and fails unless the body is the GLB's height and faces +Z
(`fbx-check.json`). The first Studio trial (2026-11-20) imported Blender's default FBX at 605 studs,
facing away. The person turned each part on its own, and that left the hair over the face. The same
read-back on that file gives 604.98 studs, -Z. `kit_look.py fbx <folder>` rewrites an older folder's
FBX and re-audits it.

**A detail the look should not have** (the Bouncer's magenta zip, which TRELLIS copied from the
picture) goes in `--remove "<the detail, where it is>"`, repeatable. It is taken out in the T-pose
edit, before the 3D model, and not repaired in the texture afterwards. Changing the list redoes the
build from the edit onward and moves the earlier build to `superseded/<time>/`. A rerun without
`--remove` keeps the stored list.

**Front and back are painted from pictures.** After TRELLIS, `character` has Kontext draw the back
(`tpose/back-<seed>.png`). `back_score` rejects a back that is really the front again: it must change
by at least 0.37 of the front's own colour spread, and the face skin must be gone. Then
`project_picture.py` paints the T-pose onto the front and the back view onto the back
(`trellis/model-painted.glb`, the prep's source). The sides keep TRELLIS's paint, because Kontext
can't draw a T-pose in profile: the arms reach forward. On 2026-11-20, the free alternatives all lost
to this (`trials/DarkArmourAuto/multiview/comparison.jpg`): TRELLIS v1 multi-view, Hunyuan3D 2.1
and Hunyuan3D 2mv (forearms missing). Tripo P2 multi-view from the same front and back
(120 credits) looked better still (`comparison-tripo.jpg`).

**`--generator tripo`** runs Tripo multi-view from the T-pose and the back view. Without `--confirm`
it prints the credit estimate and stops. The prep settings differ by generator:

| | TRELLIS | Tripo |
| --- | --- | --- |
| Turn | 0 | -90 (P2 writes the front along +x) |
| Bake cage | 6 | 1 |
| Hair | cut off at `hairCut` | left on the head |

On Tripo, a wider cage baked the hidden face (inside the collar, under the hair lock) onto the jaw as
jagged brown. Cutting the hair left a gap line at the hairline. Worked example:
`trials/DarkArmourTripo`.

**`--generator tripo-argon` (or `kit_look.py character-argon <Name>`)** runs the duplicated **Tripo Argon pipeline** (`tools/blender/measure_joints_argon.py`, `prepare_avatar_setup_argon.py`, `pose_matrix_argon.py`) for side-by-side testing without touching the baseline Tripo path:
- Pass `--reuse-from <TrialFolder>` to reuse an existing trial's `tripo/model.glb` at **0 credits**.
- Measures `armInner` via horizontal BVH raycasts (fixing blocky torso walls collapsing `armInner` to the centre lapel seam on `GoldenOniTripo`).
- Guards the head, mask and neck from `arm_weight` displacement, despills asymmetric side rim-lighting (`BouncerTripo`), boosts emissive accent contrast (`StormStoneTripo`), splits fused long-coat/skirt webbing below the crotch, protects head/hand/joint density during decimation, scales Head & UpperTorso UV islands (`1.65x` / `1.3x`), and bakes `BodyNormal.png` + `BodyRoughness.png` alongside `BodyColor.png`.
- Rotates the rifle proxy with `Hand.R` in non-aim poses, isolates cross-leg heat weights below the hip, and adds `sheet-team-silhouette.png` (Red vs Blue team bands and 50-stud distant dark/bright map renders).

**`--generator meshy`** is the same route on Meshy multi-image to 3D (the user's monthly plan, key in
`MESHY_API`). The front T-pose and the back view go in as data URIs. Settings:
- `latest` = Meshy 7.1, which takes the first image as the front.
- 30 credits per run.
- 2K texture: Roblox caps textures at 1024, so 4K/8K buy nothing.
- `remove_lighting` on, which strips the picture's lighting.
- No forced pose by default (`--meshy-pose none`; forcing `t-pose` remade the hands), remeshed to
  30,000 triangles.

Without `--confirm` it prints the cost and the plan balance and stops. The task id is saved to
`meshy/task.json` before polling, so an interrupted run picks the same task back up instead of paying
again. A failed task is refunded and its id cleared. Prep starts on Tripo's settings (cage 1, no hair
cut). Worked example: `trials/DarkArmourMeshy`, built from DarkArmourAuto's T-pose and back view.

Variant test (2026-11-21, `trials/DarkArmourMeshy/meshy-variants.jpg`, about 150 credits), each step adding one change:

| Variant | Change | Result |
| --- | --- | --- |
| A | `--meshy-pose none` | Pointing hands gone. Forcing `t-pose` on a picture that is already a T-pose remade the hands. |
| B | A + `--meshy-geometry 2k --faces 19000` | Smoothest face, truest colours. The defaults are now `none` and `2k`; pass `--faces 19000` yourself. |
| C | B + `--meshy-texture-ref` | Worse: the chest core turned into a black hollow and the eyes went blue. D also used the reference and kept the core, so this may be one run's luck; unproven either way. |
| D | C + `--meshy-sides` | Side views from Meshy image-to-image (nano-banana-2, 6 credits each) gave the most back and side detail, but added a smile and smaller shoulder pads. Check `meshy/sides.png` first. |

Nano-banana draws a true T-pose profile with the arm end-on, which Kontext never managed.

**D is the standard Meshy route (user's choice, 2026-11-21: "if people are going to buy these I need to
provide a high quality product").** Its defaults:
- `--meshy-sides` and `--meshy-texture-ref` are on; turn them off with `--no-meshy-sides` or
  `--no-meshy-texture-ref`.
- `--faces` is 19,000 for meshy.
- A build costs about 47 credits.
- The side-view prompt now asks for the front picture's exact expression and shoulder-pad size, after
  D's side views widened the picture's slight smirk into a grin and shrank the pads. Check a mouth
  against `source/picture.*` before calling it wrong: the DarkArmour picture smirks.
- `trials/DarkArmourMeshyStd` is the worked example: the standard route plus gloves, about 53 credits
  including one side-view retry.

**Hair on Meshy builds is split off as its own part (`hairSplit: "colour"`, set by `kit_look.py` for
meshy).** Meshy sculpts strand grooves, but it fuses the hair onto the head. Kept in the body, the hair
shared the body's triangles and its 1024 texture, and the voxel fuse smoothed the grooves away.

How the split works:
- A flood from the crown takes faces that are neither skin nor bright glow.
- Below the measured hairline (`hairLine`) it takes only faces as dark as the crown's own hair, so it
  stops at the collar by colour.
- The hair keeps Meshy's sculpt: thinned to 5,000 triangles if needed, never voxel-remeshed.
- It gets a fresh 1024 texture of its own.
- The body drops to 15,000 triangles, so the character stays inside 20,000.

A fixed height floor cut the back of the hair in a sawtooth, which is why the stop is by colour.
Before and after: `trials/DarkArmourMeshyStd/hair-before-after.jpg`.

**When the top of the head isn't hair, build with `--headgear`.** On a horned, helmeted or hooded
character, the split's "crown colour" is the horns. On HornedFeatherMeshy it pulled parts of the horns into
the Hair part and left holes. `--headgear` skips the split, so the horns and hair stay on the body.

**Blond and light hair** are told apart from the character's own skin, measured on its face. A fixed
warm-colour skin test matches blond hair, and this left SoldierMeshy's hair unsplit and painted navy.
Light hair also gets no painted sheen.

**Hair sheen is painted back (`hairSheen`).** The picture's glossy highlight across the hair is
lighting, so Meshy's `remove_lighting` strips it.
- **Colour:** `kit_look.hair_sheen` reads it from the top of the T-pose picture. It takes the brighter
  half of the coloured hair pixels and pushes their saturation up 1.7×, because their mean reads greyer
  than the gloss looks. If the highlights are neutral it uses the brightest tenth; for light hair or a
  helmet it returns none.
- **Painting:** `paint_sheen` screens that colour into the hair's own texture as a band where the hair
  faces up and forward. The light direction is (0, -0.75, 1), and the ramp runs 0.6 → 0.74.
- **Clean edges:** the band is placed from a smoothed copy of the shape, so it sweeps cleanly.
- **Strength:** 0.7.

What failed on the way (`hair-sheen-before-after.jpg` shows the result):
- A wide band came out as a dull wash over the whole crown.
- Flat normals gave it blotchy edges.
- Unboosted, the colour came out lilac.

Under bright flat light it reads strong. Judge it under Studio lighting before tuning the strength.

**Hands (`--hands glove`, the default for meshy only).** On a Tripo build (a copy of BouncerTripo) the
glove came out undersized and off-centre inside the open, puffy sleeves, with a hole at the sleeve end.
It is sized from the wrist, and those sleeves are wider and open. Meshy's gauntlets close at the wrist.
Until the glove sizes itself to the sleeve opening, tripo and trellis keep their own hands. No generator made sellable hands: TRELLIS
mitts, Meshy fused fingers, a pointing finger or thumbs-up mitts, Tripo claws. The prep (step 2b) now
cuts each hand off at the measured wrist and plugs in a chunky closed-fist glove built from rounded
blocks (superellipsoids):
- one fist block,
- four finger ends with grooves between them,
- a thumb lying across the front.

The glove is sized from the arm's radius at the wrist and tinted with the darker half of the paint of
the hand it replaces. The voxel fuse welds it into the cuff.

Two earlier designs failed:
- A flat open hand from boxes came out of the fuse as a thin paddle.
- Box finger segments came out as a hook with its thumb lost.

Keep every part a few voxels thick. The fist reads from every side and closes round the rifle grip in
every pose (`trials/DarkArmourMeshyD/skinned/hand-views.png`). `--hands keep` keeps the generator's
hands.

## Layered clothing: what goes wrong and why (2026-11-22/23)

Learned on four clothed Meshy builds: GreySuit, BlackSuit, BlackCoat and LabCoat (`trials/four-final.jpg`).
Meshy models a dressed character like a real one: skin, shirt, jacket and lining are separate shells
stacked inside each other, and it paints every surface no light reaches near-black. Roblox needs one
closed body, so the prep fuses the layers and cuts the hands off. **Every defect below was an inside
surface that our own cutting or bending exposed.** Read a new defect that way first.

| What showed | Cause | Fix, now in the prep |
|---|---|---|
| Black splotches on the suit when posed | 21-33% of faces are hidden inner walls and creases, 84% of them painted near-black | `recolour_hidden` (prepare): faces seen from no direction, and dark faces seen from fewer than 6 of 64, are repainted from the cloth that covers them. It ships in the model. |
| Shirt and tie sliding through the jacket in poses | heat weighting reached the jacket but not the layers under it | preview only: `proxy_weights` (pose_matrix) weights a voxel stand-in at 0.06 and copies it on, so the layers move as one |
| Skin and black shards round every glove | the cut at the wrist left the old hand's stubs, the shirt cuff and the lining as ragged slivers | `tidy_wrist`: drop anything near the cut that has cloth further out along its radius; drop loose scraps; pull stragglers back onto the cut plane |
| Black spikes between the lab coat's cuff and glove | the cuff's own end face, a dark ring facing down the arm, uncovered and not hand-coloured | `tidy_wrist` also drops dark faces facing down the arm at the cut. It needs the "dark" test: without it, the rule also removed the teal cuff band |
| A chip hanging in the air beside the shoulder | a 30-vertex island left by the voxel fuse; it took the torso's weights | islands under 1% of the body are dropped (the old floor was 50 faces) |
| Straps flying out sideways in the jump | thin straps hanging free below the hem get dragged by the nearest limb | `"remove"` boxes in the trial's `joints.json` marks trim them before the fuse (`trials/LabCoatMeshy`) |

**How to fix the next one (what made this take several rounds):**
- **Measure before you change a rule.** Three guesses at the lab coat's spikes changed nothing. A layer map
  settled it in one run: `"debugWrist": true` in a prepare spec prints each wrist's faces by distance along
  the arm (t) and from its axis (d), in units of the wrist radius, with brightness and whether the tidy cut
  them. A flat-grey render is the same move for paint: clean geometry in grey means the fault is paint.
- **Fixed radii fail on the next costume.** A cuff can be tight (suits) or flared (lab coat), so test what
  covers a face, not how far out it sits.
- **A rule that removes faces needs a colour or cover test, and a look at what it took.** The bare end-face
  rule fixed the spikes and silently ate the teal cuff.
- **Tell preview-rig faults from model faults.** Studio rigs the FBX itself, which has no skeleton. Shoulder
  points with the arms down, and a jacket hem tearing into teeth over a raised thigh, come from our approximate
  preview weights. Stray paint, shards, loose chips and dangling straps are in the model. Say which kind a
  defect is in the findings, and settle preview-rig faults with a Studio test, not more preview tuning.
  Weight smoothing was tried for the hem: 4 passes barely helped; 12 smoothed the hem but tore the sleeve
  and opened the knee, and stretch rose from 3.5% to 9.4%. It stays off (`POSE_WEIGHT_SMOOTH=n` to try).
- **Blender hides failures unless `--python-exit-code 1` comes before `--python`.** With it after, a crashed
  pose step exited 0 and the audit copied the previous night's renders. `kit_look.py` now orders it right
  everywhere it runs prepare, audit and the pose test. Check render timestamps if a fix "did nothing".
- **Design out what the prep cannot fix.** Capes over the shoulders webbed the black coat's arms to its body,
  and a picture with sloped arms gave a sloped T-pose that Meshy's own t-pose mode kept. Redraw the picture
  (level arms, no capes) rather than fighting it in Blender. Accessories at the wrist (a watch, a bracelet)
  are cut with the hand; leave them out of the picture or expect a ring at the cuff.

**`kit_look.py aragon-meshy <Name>` (or `character <Name> --generator aragon-meshy`)** runs the **Aragon Meshy Full Pipeline**:
- **`--mode direct` (default, 35 credits, 0 HF GPU quota):** Sends the original full-resolution concept image directly to Meshy 7.1 `/image-to-3d` with `pose_mode: t-pose`, `geometry_resolution: 2k`, and `remove_lighting: true` (preserving fine accessories like wrist watches and badges that FLUX Kontext drops, while T-posing once in 3D).
- **`--mode multiview` (Variant B settings, 35 credits):** Runs the Kontext T-pose + back view into Meshy 7.1 `/multi-image-to-3d` with `pose_mode` omitted (`none`, keeping open hands), `geometry_resolution: 2k`, `remove_lighting: true`, and `textureRefs` off.
- **`--reuse-from <TrialFolder>` (0 credits):** Reuses an existing trial's `meshy/model.glb` (or `tripo/model.glb`) for side-by-side comparison.
- Runs the full Argon prep & 8-sheet audit at `18,500` triangles (`measure_joints_argon.py` -> `prepare_avatar_setup_argon.py` -> `write_fbx.py` -> `audit_skinned.py` + `pose_matrix_argon.py`).

Prep rules that now apply to every generator:
- A small loose piece above the neck is kept as part of the body if its area is at least 30e-4 of the
  height squared. Tripo's purple hair lock measured 66; TRELLIS slivers measured at most 15.
- The `paint` box repaints only skin-coloured faces, and only when skin covers 35% or more of the box.
  That's TRELLIS's skin-over-hair failure; a few ears inside the box isn't.

**What's left for me and the user:**
- I read every sheet and record `findings`.
- People approve the picture and do the Studio run.
- Joints and seed choice are no longer judgement calls; check the joints overlay on the audit.

What the steps below found by hand is now inside that command.

Tripo is not needed for a skinned body (2026-11-20; Bouncer and the DarkArmour trial):

1. Edit the user's picture into a straight-on T-pose with FLUX.1 Kontext (free). Widen the canvas
   first, or the hands get cut off at the edge. Posing in the picture beats swinging arms in
   Blender: TRELLIS fuses sleeves to the jacket, and a Blender swing tore it into spikes and flaps.
2. TRELLIS.2 on that picture (free, about 80 s of the daily GPU quota).
3. Read the joints off a grid render, then run `kit_look.py skinned <Kit> --source <glb> --turn 0
   --swing 0 --marks '{..., "hairCut": z}'` (or `prepare_avatar_setup.py` with a spec, for a
   trial). TRELLIS fuses hair to the head, so `hairCut` lifts everything above the brow into the
   hair. Debris shells are dropped, and `headgearIsHair` folds split-off locks into the hair.
   `paint` boxes with `"color": "hair"` cover skin TRELLIS painted where the hair should wrap.
4. **The visual audit runs before anything is reported or handed over, whatever the route.**
   `kit_look.py skinned` renders it itself; otherwise run `kit_look.py audit <folder>`. Read every
   sheet: six views, front and back close-ups, and each accessory alone in flat colour. Then
   `kit_look.py findings <folder> --defects "..." --passed "..."`. `kit_look.py ready <folder>`
   exits 1 until the findings cover the current files; run it before sending an FBX. The
   DarkArmour trial went to the user with a "headgear" that was floating slivers, and nobody had
   looked at the back.
5. Then the pose test: `blender -b -noaudio --python tools/blender/pose_matrix.py -- <folder> --out <dir>`.
   It uses an R15 skeleton at the match body's heights, heat weights, and the idle, walk, run,
   crouch, aim, jump and head-turn poses. When heat weighting finds no solution (the Tripo body
   fused from 24 overlapping shells), it says so and falls back to nearest-bone weights.

TRELLIS loses glow (emissive lines come back dark) and rounds spikes and fingers at 12,000
triangles. That is the surface pass, after movement passes.

## Tripo for shape, Blender for surface

Each Tripo run is 120 credits and comes back different. Use it only for a piece's shape. Fix
colour, material, worn edges and glow in Blender (`finish`, free and repeatable), and fit,
gaps and handedness in the slot table and look.json. Simple shapes (a sleeve, a glow plate,
a strap) are Blender or Roblox parts, never a Tripo run. Re-run Tripo only when the shape is
wrong: a slab, a stray flap, the wrong piece, a part over its triangle allowance.

Settle the triangle allowances before the game, not at upload: re-export a piece that is over
from Tripo at its face count when it is first filed. The knight went in with six pieces over
their own allowance (19,171 of 20,000 overall).

## Rules

- Never upload or put a look in the game without the user's words about the review sheet.
- A piece over its allowance is fine for review. Before the game it is re-exported from Tripo at
  the allowance; never cut it down ourselves (our reduction tore Tripo meshes every time).
- Any mesh over 10,000 triangles cannot go into Roblox at all.
- The look is cosmetic: pieces are massless and non-colliding in game, and the R15 hitbox does
  not change. Team colour still has to read (a trim, or the glow) — say how in the bar.

## Into the game

9. `verdict <Kit> --looks good --said "..."` records the user's words about the review sheet,
   tied to the exact pieces on disk.
10. `export <Kit>` refuses unless that verdict matches the pieces. It writes one GLB of every
    fitted piece in the rest pose (textures cut to 1024, Roblox's cap), and the registry entry
    `<kit-id>-look` with each piece's body part and offset in studs, and the parts it hides.
11. `publish <Kit>` is a dry run; `--confirm` uploads, only on the user's go-ahead.
12. `KitLookService` (server) welds the pieces to the body parts (massless, no collision, touch
    or raycast; hitbox unchanged), hides the parts the armour replaces, and scales with the
    avatar. It dresses a player whose `Kit` attribute names the kit (KitService, not built), or
    everyone when Tuning `Debug_KitLook` names it. Stop/Start Studio to test.

Studio checks still owed for each look: it loads, faces forward, left and right are not
swapped, it scales on a non-default avatar, it animates (walk, jump, crouch, slide, aim), and
team colour reads. Nothing here gives the look a team colour yet; the bar's `--team` records how
it should, so KitService can build it once it exists.
