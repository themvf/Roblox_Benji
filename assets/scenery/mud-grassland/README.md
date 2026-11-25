# Mud Grassland

Source page: https://sketchfab.com/3d-models/mud-grassland-9d49d4797ee24d9bb617aa4142dc4006

This package is prepared for the reusable scenery pipeline. The current source is
`MapLocations/mud-grassland/source/Untitled.glb`, with textures in
`MapLocations/mud-grassland/textures`.

## Build

1. Run:

```powershell
python tools/scenery/pipeline.py build --package assets/scenery/mud-grassland
python tools/scenery/pipeline.py verify --package assets/scenery/mud-grassland
```

The export is scenery, not playable terrain. Review it in an isolated Studio folder,
keep decorative parts non-collidable, author simple collision separately, and place it
outside the map's playable bounds unless the design packet explicitly approves it.
