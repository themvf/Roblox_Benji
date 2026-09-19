# Roblox_Benji project conventions

Rivals-style Roblox arena shooter, pivoting to objective play (Convergence). Rojo + Wally + Knit, Weapons Kit for
guns, Lune for build scripts. Read README.md for the full map of services.

## Toolchain
- Tools come from Rokit (`rokit.toml`): rojo 7.7, wally, stylua, selene, lune. Run them from the project root.
- `rojo serve` owns one terminal tab; run checks in another tab or Rojo stops.
- Before committing: `stylua src && selene src && rojo build -o /tmp/arena.rbxl`. Zero warnings is the bar.
- Build gates: `lune run tools/check_skins.luau`, `lune run tools/check_celebrations.luau`,
  `lune run tools/check_maps.luau`,
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

## Editing rules that avoid wasted turns
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

## UI and screens
All on-screen UI goes through `src/client/UI/Screen.lua`: safe-area insets, device class, a UIScale per
panel, 44pt tap targets, one DisplayOrder table, and reserved zones (crosshair, thumbstick, jump button,
hotbar). Never build a raw `ScreenGui` or position off a raw screen edge. World-space `BillboardGui` sizes
go in scale (studs), never offset (pixels). Use the `roblox-ui-layout` skill (.claude/skills) before adding
or moving any HUD, button, panel or billboard; it holds the rules and the multi-device QA gate.

## Map building
Use the `roblox-map-building` skill (.claude/skills) before adding or editing a map layout. It holds the geometry
audit checklist, the safety data every map must declare, and the QA gate.
