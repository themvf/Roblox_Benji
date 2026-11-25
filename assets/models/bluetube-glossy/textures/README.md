# Material delivery

The clean rebuild uses ten named glTF PBR materials with embedded color, metallic, roughness, emission and alpha factors. No image texture maps are used by `exports/BlueTube_Glossy.glb`. The factor values are reproducible in `tools/blender/build_bluetube_clean_geometry.py` and the editable `.blend` file.

The former finish-only metallic-roughness image belongs to the rejected jagged-mesh trial and is preserved in `trials/BlueTube_FinishOnly_MetallicRoughness.png`.

## Studio-textured blue copy

`exports/BlueTube_Glossy_StudioTextured.glb` embeds the 24 PNGs in `studio-textured/`: one color and one packed metallic/roughness map for each of the ten materials, plus four emissive maps. The green, yellow, cracked and occupant copies embed corresponding PNGs in `studio-textured/{green,yellow,cracked,occupant}/`. Run `python tools/build_bluetube_studio_textured.py` from the repository root to reproduce the textured copies from their original exports, or pass variant names to build selected copies. These are small, uniform maps that carry the original factor values through Studio's texture import path; they are not new painted detail. The original factor-only GLBs are preserved. Studio import and appearance remain unverified.

The blue cracked-and-spilled sixth variant has its own 34 embedded maps in `studio-textured/bluecracked/`. Run `python tools/build_bluetube_blue_cracked_oozing.py` first to derive its geometry-preserving blue GLB and textured copy. That builder renders and validates the result. Studio appearance remains unverified.
