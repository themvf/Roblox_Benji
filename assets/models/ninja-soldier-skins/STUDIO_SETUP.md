# Studio verification for character skins

Confirm the intended game/place before changing an open Studio session. Sync the repository through the project's usual Rojo workflow, then start a new Play session so scripts reload. These skins are generated from Lua definitions under `ReplicatedStorage.Shared.CharacterSkins`; importing the armor GLBs is not needed for this implementation. Do not upload duplicate GLBs unless a later, approved mesh-based version requires them.

In an R15 test avatar, open Customize → Character and preview/select each option. Start a match and check the front, sides and rear while idle, running, jumping and using a weapon. Check that armor follows joints, does not collide, retains team readability and does not obstruct the camera or muzzle. Die and respawn, end the match, then verify the normal avatar returns in the lobby. Rejoin to check selection persistence. Repeat for the default avatar. Record the tested place ID, observed behavior, screenshots and any needed corrections in `HANDOFF.md`.

These are match appearances, not map props. There is no map placement or decoration collision setup.

For the later full-character Marketplace versions, use the approved clean body and armor package in Roblox Avatar Setup with the **Platform Avatar** preset. Verify its dynamic head, R15 motion, cages, accessory fit, body-region triangle budgets and output asset IDs. Run this separately from the game's skin-selector playtest. See `MARKETPLACE_DELIVERY.md`; the current block armor and detailed segmentation trials are not suitable inputs for Marketplace publication.
