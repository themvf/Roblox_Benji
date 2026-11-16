---
name: asset-from-prompt
description: Make a new 3D game asset from a one-line description with no check-ins along the way (text -> reference image -> TRELLIS mesh -> game-ready GLB, local verification). Use whenever the user asks for a new prop, vehicle, tree, character or other model and has no reference image or GLB, e.g. "make me a black hawk helicopter" or "I need a palm tree for the island map".
---

# Asset from a prompt, hands-off

The user gives one sentence. You ask the intake questions once (see "Ask first, once"), then run stages 1-4 of
[ASSET_DELIVERY_WORKFLOW.md](../../../docs/design/ASSET_DELIVERY_WORKFLOW.md) yourself and come back
once, with the finished local build. The user said plainly that they do not want to be involved in the
intermediate steps: do not ask them to choose a seed, approve a prompt or look at a sheet mid-run.

You make every call below. Write each one down in the package so the user can overrule it afterwards.

## Your defaults, offered with the questions

| Decision | Rule |
|---|---|
| Package name | kebab-case from the request; check `assets/models/` so you do not reuse one |
| Role | `decor` unless the request says players hide behind it (`cover`) or use it (`interactive`) |
| Height in studs | real-world height in metres x 3 (a 1.8 m person is about 5.5 studs), unless a size is given |
| Style | `realistic` for vehicles, scenery and props; `blocky` for Roblox-style characters; `stylized` when asked for low-poly or cartoon |
| Aspect | `wide` for vehicles and anything longer than tall, `tall` for trees, towers and standing figures, else `square` |

## Ask first, once

Before anything else, run `python tools/asset_generate.py questions` and put those questions to the
user in **one** message (use the question tool if you have one). Skip any the request already
answers, and offer your default from the table above where one applies so they can just agree. Do
not start generating while you wait. This is the only check-in: once they answer, the run is
hands-off and you report once at the end.

Record every answer with `brief` (`--purpose --role --kind --height --where --copies --moving
--share`, plus `--game-name` and `--length` where they apply). If the user says "you decide", choose,
and record what you chose with `--assumed "..."`; repeat those choices in your final report.
`reference` and `generate` refuse to run until the brief holds the answers.

The user asked for this on 2026-11-16: they would rather answer a short list up front than have a
forgotten detail (drivable, held, how many on screen) decided silently and built wrong.

## The run

All commands are `python tools/asset_generate.py ...`; the file's docstring has the full reference.
`HF_TOKEN` must be set or the Spaces give almost no GPU time.

**Brief first.** Before step 2, run `brief <name> --purpose "..." --role ... --height ...`;
`reference` and `generate` stop without it. Roles: `held`, `interactive`, `cover`, `decor`,
`scenery`. The role sets the triangle budget and the route. If `brief` prints that the route is
clean (anything held, ridden or driven), the generated mesh is only a shape guide: generate one
candidate, then write `tools/blender/build_<name>.py` from shapes
(`tools/blender/build_military_wave_runner.py` is the worked example). If the user says it is drivable or
rideable add `--kind vehicle --game-name <Name>`; if it is a gun add `--kind weapon --game-name
<Name> --length <studs>`. Those need mounts (`--mount DriverSeat=x,y,z` and `HullCentre`, or `Grip`
and `Muzzle`; studs from the pivot, -z forward) before `build` passes, and game code that
`docs/design/ASSET_DELIVERY_WORKFLOW.md` lists per kind; report that code as not done unless asked
to write it. Read `review/mounts.png` after the build. Commands claim the package
for this session; if one says another session holds it, pick a different asset.

1. **Write the description** (40-80 words, full sentences). Order: what it is, overall shape, named
   parts, materials, a colour per part, condition. Say what is present, never what is absent: there
   is no negative prompt and "no pilots" tends to add pilots. Leave out background, lighting and
   camera; the tool's framing sets a pure white background.
   - Things that are usually photographed moving (aircraft, vehicles, animals) get described as a
     static display piece or a scale model, or they come back motion-blurred.
   - Thin parts (rotor blades, propellers, antennas, flags) are the first thing lost in the cut to
     10,000 triangles. Keep them for static decor and check them in the export views. If they come
     out broken, or the part has to move in game, regenerate with bare hubs or mounts and note in
     HANDOFF.md that those parts are to be added as separate meshes.
2. **References:** `reference <name> --prompt "..." --style ... --aspect ... --seeds 8`, then Read
   `review/references.png` and reject any image with:
   - part of the subject touching or leaving the frame edge
   - motion blur, or soft focus on any part
   - a wrong count of anything countable (blades, wheels, legs, fingers)
   - people, extra objects, text or a logo
   - a background that is not plain white, or a long cast shadow
   - a colour or part the description did not ask for
   Promote the best survivor with `reference <name> --use <seed>`. If the best one is right except
   for a single part (a blurred rotor, a wrong blade count), fix that part instead of re-rolling:
   `reference <name> --edit "Replace the ... with ..., crisp and in focus" --seeds 3`, Read the
   sheet, then `--use <101-103> --replace`. Edits vary a lot by seed; some redraw the whole object.
   Zoom in on the edited part before accepting it. If none survive, rewrite the
   description to address what went wrong and run once more. Two rounds, then stop and report.
3. **Mesh:** `generate --name <name> --seeds 2`, then Read `review/candidates.png`. A candidate fails
   if a view shows missing or fused parts, a flat or hollow back, or a shape that does not match the
   reference. Count the countable parts again here: the same reference gave a four-blade tail rotor
   on one seed and six on the next. Compare `openEdges` against other packages' `trials/*/appraisal.json`: TRELLIS output
   here runs around 140,000-200,000 at 290,000 triangles, so that range is normal and far above it
   is not. If both fail, add two more seeds (`--first-seed 3`). Four candidates, then stop and report.
4. **Pick, build:** the brief already exists (see "Brief first" above). `pick <name> --seed <n>`,
   then `build <name>`. `build` also fails an export that is over its role's triangle budget or
   is not the height the brief says; fix the brief or the build, or record
   `brief <name> --budget-waiver "<reason>"` when the excess is justified. The build retries a finer tile grid by itself
   when a mesh is over the triangle cap (up to five attempts) and writes the grid that passed
   into `brief.json`. Only if it still fails, set `"scene": {"decimate": N, "tile": [nx, ny]}`
   by hand: more cuts along the long axis, an even count across it, `decimate` no lower than
   15% of the source triangles.
5. **Audit the export.** `build` ends by running `audit`, which is the file that would be
   uploaded seen from ten sides plus six close-ups. Read both sheets every time:
   - `review/audit.png`: reference top left, textured views (brightened, so dark assets show
     detail), then the hole map. Compare against the reference part by part and recount
     anything countable; a part hidden in one view shows in another.
   - `review/audit_closeups.png`: surface quality. Look for crumpled panels, smeared texture,
     fused or broken thin parts.
   - Hole map: grey is a front face, magenta a back face. Roblox draws one side only, so a
     magenta patch is see-through in game. Hairline magenta along seams is normal for
     generated meshes (the Black Hawk shows up to 0.8% per view); `audit.json` flags a view
     only when it holds a solid patch. An opening with grey behind it is a modelled recess,
     not a hole.
   - Unsure about one spot: `audit <name> --focus x,y,z --zoom 5` (fractions of the bounding
     box) adds a close-up pair there, and the single panels in `review/audit/` are full size.
   What to do with a finding:
   - a flagged patch, or a missing, fused or miscounted part: `audit <name> --seed <n>` on the
     other candidates, `pick` a clean one with `--replace` and rebuild; if none is clean,
     generate two more seeds. If every seed fails the same way the reference is the cause:
     fix it with `reference --edit`, delete `trials/seed-*` and regenerate.
   - crumpled panels with intact source: raise `scene.decimate` in `brief.json` and rebuild;
     the retry adds the tiles that needs.
   - Two fix rounds, then stop and report what is still wrong. Nothing here repairs a mesh
     in place; say so rather than passing a flaw.
6. **Record:** update the package's `HANDOFF.md` with the description you sent, every assumption from
   the table above, the seeds you rejected and why, and any flaw still visible in the export.

Stop at a GPU quota error and say so; finished seeds are kept and the same command resumes.

## What you bring back

One message, when the audit is done or the run has failed:
- `review/audit.png` and `review/audit_closeups.png`, sent as files (the reference is on the first)
- triangle count per mesh and whether the cap check passed
- the assumptions you made (role, height, style) in one line each
- flaws you can still see, stated plainly; a build that passed its checks can still look wrong
- the one decision that is theirs: approve it for upload, or say what to change

Never upload. Stages 5-7 (visual approval, Studio, map placement) need the user and Studio, and
`tools/roblox/upload_asset.ps1` runs only after they approve the views.
