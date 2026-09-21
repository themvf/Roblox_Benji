# Official Roblox Studio connection and asset upload

The global Codex configuration now has `Roblox_Studio`, using `cmd.exe /c C:/Users/joshb/AppData/Local/Roblox/mcp.bat`. Existing configuration was preserved; a pre-change backup is at `~/.codex/config.before-roblox-mcp.toml`. No community plugin was installed.

The official server handshake succeeds. After the user enabled Studio as MCP server, 28 tools were advertised. One initial discovery returned a Studio ID; subsequent short-lived probes returned an empty place list. This means the server installation is verified but active-place attachment still needs verification in a persistent Codex connection. Restart Codex to load its new MCP configuration, keep ENGAGE open in Studio, and check Assistant → Manage MCP Servers for the connection indicator. Use `list_roblox_studios` before selecting a target. No game content was changed during setup.

## One-time credential setup

1. Open [Creator Dashboard API Keys](https://create.roblox.com/dashboard/credentials). Create a key for this asset workflow with **Assets / Read and Write**, for the appropriate creator/resources. The uploader needs the user or group ID that will own the assets; use the same owner as the game.
2. In your own PowerShell terminal, from the repository root, run:

```powershell
.\tools\roblox\configure_upload.ps1
```

It prompts for owner type, numeric owner ID, and a masked API key. The key is saved using Windows DPAPI via Export-Clixml at `%LOCALAPPDATA%/RobloxCodex/asset-upload.clixml`, outside the repository. It is decryptable by your Windows account on this machine. Do not paste the key into chat or source files.

## Upload and insert

Dry run (no credentials or network requests):

```powershell
.\tools\roblox\upload_asset.ps1 -DryRun
```

Upload the prepared entrance slice:

```powershell
.\tools\roblox\upload_asset.ps1
```

The wrapper decrypts the saved key only for its Python child process. The uploader sends the self-contained GLB to the official Open Cloud Assets endpoint, polls the returned operation, and reports an asset ID. Receipts outside the repository prevent repeated runs from uploading the same file/owner again. If a POST response is lost, it stops and requires inventory inspection rather than guessing whether to retry. Completed uploads still require moderation/availability checks in Studio.

Then use Studio MCP `insert_asset` with that ID and the intended open Studio instance. Check the imported scale/materials before executing `assets/environment/snow-fortress/entrance-kit-v1/setup_imported_slice.luau`. That setup is for an isolated review place, not a blind replacement of ENGAGE's map geometry. Match integration must preserve the current ramps, launch lanes, staircase slots and objective layout.

## Verification

`python tools/roblox/test_upload_asset.py` checks upload/poll completion, duplicate suppression, uncertain responses and network-free dry runs using a fake transport.

### Entrance upload status

The assembled `SnowFortress_ReviewSlice.glb` was successfully uploaded as asset **136223303527413**, owned by user **3678531109**, with moderation state **Approved**. File SHA256: `4a0ffb1cf27e7ba600ca08eb79946d8679e8c1b1bb9c1f521d71719d1de3d428`. Reuse this asset; another upload is unnecessary.

Inserted into ENGAGE (place ID `121549226728648`) in Edit mode as `Workspace.SnowFortressReviewSlice`. The review entrance origin is `(0, 1000, 0)`, isolated above gameplay. All 55 imported mesh parts are anchored, and all 49 architectural SurfaceAppearances have color, normal, roughness and metalness maps. Authored box collisions and three interior lights are installed. Studio raycasts verified a clear doorway, solid jamb and solid floor. The review spawn is disabled to preserve normal lobby spawning. Visual appearance and player movement still require user testing; this is not the live Convergence fortress replacement, and the Studio place has not been saved/published by this workflow.

The uploaded staging ground arrived at 600 x 110 studs. Its Studio instance was corrected to 110 x 110; the exporter now assigns the complete dimensions vector before updating Blender's dependency graph. The already-uploaded GLB remains unchanged. The insertion tool also oriented the model to the viewport; all imported parts were transformed together using the ground's inverse CFrame before collision setup.

To inspect, select `Workspace.SnowFortressReviewSlice` and press F. To walk around, start Play, remain in the lobby, switch Studio to the server context, and run this in the Command Bar:

```lua
local p = game.Players:GetPlayers()[1]; if p and p.Character then p.Character:PivotTo(CFrame.new(0, 1000, 38)) end
```

Save the place to preserve the imported review model. Toggling Studio's MCP server off and on restored discovery. `studio_session.py` keeps a JSON-RPC stdio connection alive across sequential calls; do not send secrets through it.

`python tools/roblox/studio_probe.py` performs a temporary read-only MCP handshake and place discovery; when one place is available it reads its mode and creator metadata. It makes no game changes.

Sources: [Roblox Studio MCP](https://create.roblox.com/docs/studio/mcp), [Open Cloud asset upload](https://create.roblox.com/docs/cloud/guides/usage-assets), [API keys](https://create.roblox.com/docs/cloud/auth/api-keys), [Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).
