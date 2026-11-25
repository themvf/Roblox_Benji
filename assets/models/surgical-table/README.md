# Surgical-room prop set

Four independent Roblox-ready GLBs are in `exports/`:

| File | Item |
| --- | --- |
| `SurgicalTable.glb` | Three-part padded operating table with lift pedestal, wheels, support rails and adjustable back |
| `SurgicalLights.glb` | Freestanding two-head overhead lamp rig |
| `PatientMonitor.glb` | Monitor on its own wheeled cart |
| `IVStand.glb` | IV pole with wheeled tripod base and infusion bag |

Each GLB has its own centered ground pivot and can be imported, placed, hidden or duplicated independently. `source/assembly-layout.json` gives the Roblox XYZ offsets for re-creating the reference arrangement. The table runs along X with the raised head at +X. Import with Studio Scale Unit **Stud**. Scale and role remain provisional until visual approval.

The previous all-in-one candidate is preserved under `trials/SurgicalTable_Combined.glb` with its validation file and preview images. It is not the current delivery export. The original supplied GLB and reference image remain unchanged in `source/`; the original `Surgery/` files are untouched.

`tools/blender/build_surgical_table.py` is the authoritative geometry source. `source/SurgicalTable.blend` saves the editable arrangement before the individual exports are centered. `tools/make_surgical_table_texture.py` generates a subtle blue-vinyl color map, embedded in the table GLB. Other material finishes are glTF material factors.

Run `python tools/build_surgical_table.py` from the repository root to back up the prior generated files, rebuild all four GLBs, render their front/side/rear/quarter views from the written exports, and validate them. Use `python tools/build_surgical_table.py --check-only` to check saved files without rebuilding. Exact hashes, triangle counts, bounds and limitations are in `validation.json`.

These are visual props. The monitor trace is decorative, the lamp lenses do not create Roblox light instances, and there are no gameplay interactions, functional medical controls, or Studio physics settings in the GLBs. Verify each import in Studio before map placement.
