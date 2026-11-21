# Dual delivery target: game skins and Marketplace character bundles

## User decision

The user wants **both** characters as selectable skins in this game **and** as full character bundles for the Roblox Marketplace. The full character bundle choice was confirmed in this conversation on 2026-10-18. The game and catalog versions should share the same approved character design and texture source. Rifles are separate game weapons and are excluded from the avatar bundle.

## Verified current state

`marketplace_readiness.json` is the reproducible local audit (`python tools/check_ninja_marketplace_readiness.py`). Neither supplied static source nor the detailed rigid-segmentation trials have a glTF skin or a Marketplace-ready body structure. Detailed trials contain 73,404 and 66,473 triangles, respectively, versus the published 10,742-triangle maximum for a character body. The simple armor exports are below that numeric budget but are disconnected cosmetic parts, have no rig or body, and were rejected by the user for insufficient detail. Passing a triangle count alone does not make them avatar bodies. No current file has a verified dynamic head, cages, or Avatar Setup result. No game or catalog upload is observed.

## Target authoring package for each character

1. Create a clean, coherent humanoid body in an A-pose or T-pose, with a distinct neck and 15 named R15 body regions. Follow the current [Roblox Avatar Setup input requirements](https://create.roblox.com/docs/avatar-setup/auto-setup-requirements) and [character body specifications](https://create.roblox.com/docs/avatar/character-bodies/specifications). The body geometry must fit the 10,742-triangle total and regional budgets, including the head and limb caps. Design for the intended Roblox avatar scale using an official reference mannequin/rig.
2. Preserve the detailed source appearance with UV texture and normal/roughness baking onto the clean body and armor. Create watertight geometry at genuine limb boundaries. The original scans and quarter-density files are high-detail references, not Marketplace uploads.
3. Build a functional face/head under the armor helmet. Roblox's Marketplace body needs a dynamic head with eye/mouth geometry, face animation support and a cage. Keep the mask/helmet as a separate fitted accessory where needed so the underlying head remains compliant. Avatar Setup can generate missing rigging, skinning, face and cage components, but its output must be inspected and validated; the present masked scans are unsuitable direct inputs. See [Avatar Setup](https://create.roblox.com/docs/avatar-setup) and [dynamic head specifications](https://create.roblox.com/docs/avatar/dynamic-heads/specifications).
4. Model protruding helmet, antenna, backpack and other armor that cannot fit the body budget as appropriately categorized accessories. Each rigid or layered accessory must be a single watertight mesh with at most 4,000 triangles; layered accessories also need R15 weighting and inner/outer cages. Roblox's [rigid](https://create.roblox.com/docs/avatar/rigid-accessories/specifications) and [layered](https://create.roblox.com/docs/avatar/layered-accessories/specifications) specifications govern those pieces. Check how Avatar Setup packages the complete look in the selected creator account; do not assume every accessory becomes part of one catalog listing.
5. Export an editable Blender project, named textures, a Platform Avatar candidate, previews in neutral and animated poses, and local validation for each. Keep the two character packages and any accessories clearly identified. The game selection system should equip the approved uploaded body/accessory assets rather than the current block-part prototype, preserving appearance consistency across game and catalog.

## Separate validation and release stages

- **Local:** Check source provenance, triangle totals by body region and accessory, watertight geometry, UVs, texture limits, R15 naming, orientation, and posed front/side/rear appearance. A local script cannot certify Marketplace approval.
- **Visual:** Obtain user approval of both detailed designs in standing and motion previews.
- **Studio:** Confirm the intended Studio place before modifying it. Import with the correct scale/orientation, run Avatar Setup with **Platform Avatar**, inspect generated dynamic head/cages, and test idle, run, jump, swim, emotes, accessories and clothing. Correct every validation issue and save results/asset IDs. [Roblox's importer](https://create.roblox.com/docs/studio/importer) and [Avatar Setup](https://create.roblox.com/docs/avatar-setup) describe this stage.
- **Game:** Equip the same approved assets from the skin selector; verify multiplayer replication, deaths/respawns, default avatar restoration, map readability and persistence. This is independent of catalog validation.
- **Marketplace:** Confirm chosen user/group owns the assets and has [creator eligibility](https://create.roblox.com/docs/marketplace/marketplace-policy). Roblox currently requires account verification and membership for publishing, charges fees, and reviews submissions. Record rights to the underlying references and generated models. Prepare the catalog titles, descriptions, pricing and creator ownership for final user approval before any paid upload or publication. [Publishing instructions](https://create.roblox.com/docs/marketplace/publish-to-marketplace) and [fees](https://create.roblox.com/docs/marketplace/marketplace-fees-and-commissions) are authoritative at release time.

## Inputs still needed at the Studio/publication boundary

- Intended Studio place and creator account or group for these bundles.
- Rights confirmation for commercial redistribution of the supplied reference art and generated GLBs.
- Final visual approval, catalog titles, pricing and paid-upload approval.

The project does not currently contain an official R15 authoring template. Roblox provides [combined rig, cage and attachment project files](https://create.roblox.com/docs/art/modeling/project-files). The URL for the combined ZIP was identified; a local terminal download attempt failed because the sandbox could not resolve its host. Retrieve the official reference through an authorized browser/Studio path before final body authoring. Preserve its provenance and cleanup steps.
