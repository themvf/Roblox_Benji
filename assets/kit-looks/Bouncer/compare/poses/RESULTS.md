# Bouncer pose matrix, 2026-11-20

`blender -b -noaudio --python tools/blender/pose_matrix.py -- assets/kit-looks/Bouncer/skinned
assets/kit-looks/Bouncer/skinned-trellis --out assets/kit-looks/Bouncer/compare/poses`

This is a Blender stand-in for Studio's Avatar Setup:
- an R15 skeleton at the match body's joint heights;
- Blender's automatic (heat) skinning;
- the poses bind, idle (arms down), walk, run, crouch, aim, jump and head turn.

It shows whether a body *can* bend cleanly. Studio skins with its own method, so the Studio test
still decides.

| | TRELLIS (`skinned-trellis`) | Tripo (`skinned`) |
|---|---|---|
| Weights | heat; 6 of 5,978 vertices unweighted | heat found **no solution**; fell back to nearest-bone weights |
| Worst stretch (triangles over 2x) | 0.23% (run) | 7.3% (jump) |
| Worst crush (under 0.35x) | 4.1% (run, folds at hip and knee) | 2.2% (crouch) |
| Seen | clean in every pose. Arms come down from the T-pose with round shoulders; no tears at the hips or knees | jacket webs between arm and torso when the arms rise (jump, aim) |

The two numbers are not like for like. The Tripo body was weighted by the cruder fallback,
because heat weighting found no solution on it. That failure is itself a warning sign: heat
weighting fails on surfaces with internal overlaps, and the Tripo body was fused from 24
overlapping shells.

Sheets: `sheet-skinned-trellis.png`, `sheet-skinned.png`. Per pose: `pose-matrix.json`.
