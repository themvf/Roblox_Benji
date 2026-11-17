# Roblox_Benji project conventions

Rivals-style Roblox arena shooter, pivoting to objective play (Convergence). Rojo + Wally + Knit, Weapons Kit for
guns, Lune for build scripts. Read README.md for the full map of services.

For Snow Fortress work, use [SNOW_FORTRESS_REDESIGN_SPEC.md](SNOW_FORTRESS_REDESIGN_SPEC.md).
Snow Fortress is a Convergence map. Resolve its running-place/source mapping and effective Rojo tuning before implementation;
the spec records baseline discrepancies, preserved screenshots, and ordered design/verification gates.

## Toolchain
- Tools come from Rokit (`rokit.toml`): rojo 7.7, wally, stylua, selene, lune. Run them from the project root.
- `rojo serve` owns one terminal tab; run checks in another tab or Rojo stops.
- Before committing: `stylua src && selene src && rojo build -o /tmp/arena.rbxl`. Zero warnings is the bar.
- Build gates: `lune run tools/check_skins.luau`, `lune run tools/check_celebrations.luau`,
  `lune run tools/check_maps.luau`, `lune run tools/check_assets.luau`,
  `lune run tools/check_decor.luau`, `lune run tools/check_bake.luau`, `lune run tools/check_map_authoring.luau`,
  `lune run tools/check_live_map.luau`, `lune run tools/check_lobby_authoring.luau`, `lune run tools/check_movement.luau`,
  `lune run tools/build_weapons.luau` (regenerates weapon tools from `src/shared/Weapons`).
- Lune scripts need datatypes imported from the roblox lib (`local Vector3 = roblox.Vector3` etc.).

## CI (GitHub Actions)
- `.github/workflows/ci.yml` runs every gate above on push to `master` and on PRs, using the pinned `rokit.toml`
  toolchain so CI resolves the same tool versions as local. Green CI means the pre-commit list passed.
- Generated weapon tools are enforced: after editing `src/shared/Weapons`, rerun
  `lune run tools/build_weapons.luau` and commit `assets/weapons/tools/`, or CI fails. Output is
  byte-deterministic across Windows and Linux, so a diff there is always a real staleness bug.
- Every run uploads the built place file as the `arena-rbxl` artifact (14 days). That is how a cloud session
  gets a playable `.rbxl`, since `rojo build` needs `Packages/` from `wally install`.
- Line endings are LF everywhere (`.gitattributes`, `eol=lf`). Git for Windows sets `core.autocrlf=true`
  system-wide, which otherwise makes `stylua --check src` fail on every file locally while CI passes.

## Generated assets: one flow, enforced
- **Ask before you build.** For any new asset, run `python tools/asset_generate.py questions` and put
  those questions to the user in one message, skipping what the request already answers. Record the
  answers in the brief. That is the only check-in; after it, run hands-off and report once.
  `reference` and `generate` refuse to run on a brief without the answers.
- Order is brief -> reference -> mesh -> build -> approve -> publish -> Studio, all through
  `python tools/asset_generate.py`; the table is at the top of
  [ASSET_DELIVERY_WORKFLOW.md](docs/design/ASSET_DELIVERY_WORKFLOW.md). Write the brief first: its role
  sets the triangle budget and whether the mesh is kept (`scan`) or rebuilt from shapes (`clean`).
- A vehicle or a gun is `brief --kind vehicle|weapon` with named mounts (`DriverSeat`, `HullCentre`;
  `Grip`, `Muzzle`), a `--game-name`, and code the workflow doc lists per kind. `build` draws the
  mounts and the front on `review/mounts.png`; look at it. Game code reads mounts from the registry.
- Never type an uploaded asset id into a script. `publish` writes it to `src/shared/AssetRegistry.json`
  and code reads `require(ReplicatedStorage.Shared.AssetRegistry)[name].assetId`.
- `publish --confirm` uploads, so it needs the user's approval of the review sheets first.
  First read every close-up yourself and record the defects (`findings <name>`); the user gets your list.
  Show them `review/audit.png` and `review/audit_closeups.png`, ask whether it looks right up close, and
  record their own words with `verdict <name> --looks good|bad --said "..."`. "Continue" is not approval.
- Thin bars, railings, antennas or open framework (`--thin yes`) are built from shapes, not scanned, and
  nothing a player can get within 100 studs of is `scenery`. A radio tower passed every gate with torn struts.
- Gates: `lune run tools/check_asset_registry.luau` (hashes, stale uploads, budgets, template settings,
  ids typed into `src/`) and `lune run tools/check_large_files.luau` (nothing over 5 MB without a reason
  in `tools/large_files.json`). Both run in CI.
- One session per asset package. If a command says another session holds the package, work on
  something else; do not `--take-over` unless the user says that session is finished.

## External art: appraise before you build
- For asset handoff and resumption, follow [ASSET_DELIVERY_WORKFLOW.md](docs/design/ASSET_DELIVERY_WORKFLOW.md). Read the asset package's `HANDOFF.md` before rebuilding; record approved decisions and continue from the first unverified stage. The server rack is the worked example.
- A new asset asked for by description alone ("make me a palm tree") goes through the `asset-from-prompt`
  skill (.claude/skills): run text -> reference -> mesh -> local build without check-ins, report once at the end.
- **Any** model, scan or scenery pack gets appraised before a pipeline is pointed at it:
  `blender -b -noaudio --python tools/blender/appraise_asset.py -- --source "<file>" --record assets/<kind>/<name>/appraisal.json`
  Then fill in `decision`, stating what the asset is for. `check_assets` fails until you do.
- Ask what the asset is *of* and the viewpoint it was authored for. That is not the same
  question as what you want it for, and the mismatch is expensive: a top-down scan of a flat
  ice plain was decimated, exaggerated, tiled, uploaded three times and placed as a mountain
  range before anyone measured whether it could be one. It could not.
- Destination decides the tool. A prop seen from any angle is a mesh (`tools/blender/scene_kit.py`).
  A horizon is a rendered skybox (`tools/blender/make_sky_range.py`) -- nothing distant should be
  geometry. Ground the player stands on is `Terrain` data in the map module.
- Roblox's 10,000-triangle cap is **per mesh**, so tile breadth rather than decimating it away.
  Past roughly 90% reduction the silhouette is gone, and silhouette is most of what reads at distance.
- Full checklist and the four failed attempts: [docs/design/ASSET_INTAKE_AND_LESSONS.md](docs/design/ASSET_INTAKE_AND_LESSONS.md).

## Editing rules that avoid wasted turns
- For every new map, mode, or major redesign, follow [GAME_BUILD_WORKFLOW.md](GAME_BUILD_WORKFLOW.md)
  and create/update its design packet from `docs/templates/DESIGN_PACKET_TEMPLATE.md`.
  Record decisions, storyboard, shared-component ownership, and acceptance evidence; reuse existing specs.
  Honor prior user authorization and continue routine work without redundant approval requests.
- For new game modes, abilities, and UI, read [ROBLOX_BEST_PRACTICES.md](ROBLOX_BEST_PRACTICES.md).
  Use its feature checklist and distinguish implemented patterns from pending device/playtest verification.
- StyLua reformats after every write. Never string-match code that StyLua may wrap (long tables, calls with
  many args); anchor patches on short unique lines or use the Edit tool after reading the current text.
- Bash heredocs mangle `\n` inside Lua strings. Write Lua with the Write tool, not via heredoc.
- Studio only reloads scripts on Stop/Start. Map layout changes need a test restart too.
- Rojo 7.4 drops Content-typed properties (kit sounds, animations). Stay on 7.7+.

## Roblox facts that bit us
- Server-set velocity on a player character is ignored; the character is client-owned. Send a signal and apply
  velocity on the client (see LaunchController).
- The Weapons Kit locks the cursor every frame while a gun is held; free it with BindToRenderStep at Last priority.
- Knit: KnitInit of all services runs before any KnitStart. Hooks that must exist before a character spawns
  (spawn placement) go in KnitInit.
- Tweening anchored parts does not carry standing players. Elevators are a known follow-up.
- `Humanoid:PlayEmote` works for built-in emotes on R15 without uploads; custom animations need uploaded ids.
- Instances outside the Rojo tree are left alone by Rojo; `$ignoreUnknownInstances` keeps Studio-added children.

## Design rules that are now enforced by code
- Skins never change gameplay numbers (validator rejects any such key). Tier = lowest tier admitting the systems.
- Celebrations cap at 8 s, never target an opponent, need a flashing rating.
- Objective mode logic is generic; maps supply Objectives/Events/Pickups data. Never hard-code a map in a service.
- Every tunable number lives in `Config` and is exposed as a Tuning attribute so it can be changed in Studio.
- Nothing writes `Humanoid.WalkSpeed` but `Shared/Movement` and `MovementController` (check_movement fails
  otherwise). A speed effect is `Movement.setModifier(character, source, multiplier | nil)`, so effects combine
  in any order. The Weapons Kit's own sprint/aim-slow are switched off in `tools/build_weapons.luau`.

## UI and screens
The lobby world is editable in Studio through `assets/environment/source/Lobby.rbxm`.
Follow [the lobby editing walkthrough](docs/design/lobby-experience/EDITING.md): edit the
Workspace source, Play to preview, then Save to File and run `tools/save_lobby.cmd`.
Do not hand-edit the generated playable copy or the temporary `Workspace.Lobby`.

Layout goes through `src/client/UI/Screen.lua`: safe-area insets, device class, a UIScale per panel, 44pt
tap targets (96pt ceiling), one DisplayOrder table, and reserved zones (crosshair, thumbstick, jump button,
hotbar). Never build a raw `ScreenGui` or position off a raw screen edge. World-space `BillboardGui` sizes
go in scale (studs), never offset (pixels).

Appearance goes through `src/client/UI/Theme.lua`: palette, the four-step type ramp, surfaces and contrast.
Never write a `Color3.fromRGB` in a controller (3D lighting values aside) -- copy-pasted tokens are how the
team red became three values. Team colours live in `src/shared/Palette.lua` so the server and the HUD agree.
Text-bearing panels use `Theme.Transparency.Panel`, which holds contrast against a bright sky; text drawn
over the 3D world gets `Theme.overWorld`.

Use the `roblox-ui-layout` skill (.claude/skills) before adding or moving any HUD, button, panel or
billboard, or picking any colour or text size; it holds both module APIs and the multi-device QA gate.

## Map decor vs map geometry
Geometry that decides fights -- floors, walls, cover, routes, objectives -- is Lua in
`src/shared/Maps`, reviewed and fully gated. Scenery is not. A map's `Decor` list holds
props placed by asset id, and `assets/environment/decor/<Map>.rbxmx` holds whatever a
designer arranged in Studio and saved with right-click -> Save to File. Neither is subject
to the x-mirror or fairness rules; both are built into `workspace.Map.Decor`, apart from the
gameplay model. `tools/check_decor.luau` audits the one thing a designer cannot see from the
viewport: collidable decor must clear the zip lines and launch arcs. See
[assets/environment/decor/README.md](assets/environment/decor/README.md).

Scenery meant to be cover a player relies on does not go there. Author it as a block in the
map file, where the gates can see its shape.

## Map building
Use the `roblox-map-building` skill (.claude/skills) before adding or editing a map layout. It holds the geometry
audit checklist, the safety data every map must declare, and the QA gate.

New Convergence maps are authored, not written: `bash tools/save_map.sh new <Name>` makes an editable
`assets/environment/source/<Name>.rbxm` whose markers are the map data, and `bash tools/save_map.sh <Name>`
generates `src/shared/Maps/<Name>.lua` and the bake from it. Never hand-edit either generated file (check_bake
fails on drift); change the source or `<Name>.presentation.lua`. Designer walkthrough:
[assets/environment/source/README.md](assets/environment/source/README.md); decisions and evidence:
[docs/design/map-authoring/design-packet.md](docs/design/map-authoring/design-packet.md).
