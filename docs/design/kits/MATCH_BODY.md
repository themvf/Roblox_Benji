# The match body

Decided by the user on 2026-11-19: **every kit uses one standard match body in a match; the
player's own avatar is kept for the lobby.**

## The contract

- **One skeleton, one set of proportions, one hitbox** for every kit. The R15 joint heights are
  the review body's (`tools/blender/assemble_kit_look.py`, `BODY` and `JOINTS`): ankle 0.3,
  knee 1.5, hip 2.7, waist 3.1, neck 4.7, shoulder 4.55, elbow 3.5 and wrist 2.4 studs, with arms
  hanging at x = +-1.5. A kit never changes reach, movement or collision.
- **Kit-specific appearance.** Clothing, armour, head styling and accessories may change the
  silhouette, but only the look; the hitbox parts stay the standard size and invisible
  where a look covers them.
- **Weapons line up the same way on every kit.** Every kit uses the same grip attachment and the
  same test animations (walk, run, jump, crouch, slide, aim, with a weapon held).
- **The lobby avatar comes back.** On entering a match, the player's appearance
  (HumanoidDescription) is kept so it can be put back when they return to the lobby.

Standardising the body removes arbitrary player proportions from the problem. It does **not**
fix skinning or joint deformation; those remain acceptance checks for each kit.

## Acceptance: "looks good while playing"

A look passes in stages, each with its own evidence and never folded into one "done":

1. concept and proportions approved;
2. moves: the pose matrix and the game's own animations (walk, run, jump, crouch, slide, aim,
   transitions, `MovementController`'s leg bend) with no tears, holes or weapon clipping;
3. surface: texture, glow and detail, after the movement passes;
4. local visual approval (the review sheet, the user's words);
5. uploaded;
6. Studio playtest: front, back, side and low cameras, both teams, bright and dark maps,
   respawn and team change;
7. device: a phone scene with about ten of the character on screen, frame time and memory
   measured against the same scene without looks.

## Bouncer: the trial

Bouncer is the first character through this. Two routes are compared on the same moves and
cameras, and the result picks the route for clothing looks:

- **Rigid:** the whole-body Tripo model cut at the R15 joints, each part carrying a tucked band
  of its parent (`kit_look.py whole`, `assets/kit-looks/Bouncer/pieces/whole/`). This is kept
  as the comparison.
- **Skinned:** the same model prepared for Studio's Avatar Setup against this body
  (`assets/kit-looks/Bouncer/skinned/`), Development preset, then run in game as the match
  character.

Until it passes stages 2, 6 and 7, either route is an experimental match character.
