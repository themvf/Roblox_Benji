# Roblox Map Builder Plugin v1

## Goal
Create an internal Roblox Studio plugin that lets designers assemble maps from reusable gameplay and environment components without requiring engineering work for every map.

Architecture:

> Gameplay Kit + Environment Kit + Map Builder Plugin

Build this **inside Roblox Studio**, not as a separate external application.

## v1 Scope
Include:
- Asset palette
- Place
- Drag where practical
- Grid snap
- Rotate
- Delete
- Duplicate
- Metadata
- Team spawns
- Objectives
- Weapon pickups
- Speed pickups
- Jetpack pickups
- Launch pads
- Sniper perch markers
- Event triggers
- Map validation
- Basic bot-test hook

Out of scope:
- Standalone external editor
- Procedural map generation
- AI-generated layouts
- Terrain replacement
- Full publishing pipeline
- Multi-user collaborative editor

## Asset Categories

### Structure
- Floor/deck
- Wall
- Doorway
- Stairs
- Ladder
- Catwalk
- Corridor
- Platform
- Ramp

### Cover
- Small
- Medium
- Full
- Crates
- Machinery
- Barricade
- Blast shield

### Gameplay
- Team spawn
- Objective
- Weapon pickup
- Speed pickup
- Jetpack pickup
- Launch pad
- Sniper perch
- Recovery zone
- Boundary marker

### Events
- Flyover path
- Hazard
- Sound trigger
- Kraken anchor
- Phase event trigger

### Decoration
- Radar
- Antenna
- Fuel cart
- Light
- Pipe
- Sign
- Console
- Background ship anchor

## Environment Kits
Initial themes:
- Carrier
- Jungle
- Arctic
- Oil Rig
- City

Gameplay components remain universal.

## Asset Metadata
Recommended attributes:
- AssetId
- Category
- Role
- Theme
- SnapSize
- GameplayComponent
- ObjectiveId
- TeamId
- TargetId
- ValidationType

Example:
```text
AssetId: Carrier_Cover_Medium_01
Category: Cover
Role: MediumCover
Theme: Carrier
SnapSize: 4
GameplayComponent: false
```

## Plugin UI
```text
MAP BUILDER

STRUCTURE
[ Floor ] [ Wall ] [ Stairs ]
[ Catwalk ] [ Door ] [ Platform ]

COVER
[ Small ] [ Medium ] [ Full ]
[ Crates ] [ Barricade ]

GAMEPLAY
[ Spawn ] [ Objective ] [ Weapon ]
[ Speed ] [ Jetpack ] [ Launch Pad ]

EVENTS
[ Flyover ] [ Hazard ] [ Kraken ]

TOOLS
[ Validate Map ]
[ Test With Bots ]
```

## Placement Workflow
1. Select asset.
2. Ghost preview appears.
3. Preview snaps to grid.
4. Rotate as needed.
5. Click to place.
6. Plugin stores it in correct map folder.
7. Required metadata is written automatically.

No manual scripting should be required for standard components.

## Core Controls
- Place
- Rotate 90°
- Optional fine rotation
- Duplicate
- Delete
- Grid snap toggle
- Snap size selector
- Move
- Show/hide gameplay markers

Use Studio native undo/redo where possible.

## Gameplay Components

### Team Spawn
On placement:
- Assign team
- Register spawn ID
- Validate floor beneath
- Check boundary inclusion

### Objective Zone
On placement:
- Require unique ID
- Create capture volume
- Register HUD marker
- Register bot target
- Register telemetry region

### Weapon Pickup
On placement:
- Select weapon
- Set respawn timer
- Create interaction trigger
- Register telemetry

### Speed Pickup
On placement:
- Set duration
- Set multiplier
- Set respawn

### Jetpack Pickup
On placement:
- Set fuel duration
- Set respawn

### Launch Pad
On placement:
- Require target point
- Store destination
- Preview trajectory
- Validate landing zone

### Sniper Perch
Marker only in v1:
- Validation
- Bot behavior
- Telemetry

### Event Trigger
On placement:
- Select event type
- Select trigger condition
- Link target region/object

## Map Hierarchy
```text
Map
├── Geometry
├── Cover
├── Gameplay
│   ├── Spawns
│   ├── Objectives
│   ├── Pickups
│   ├── LaunchPads
│   └── Recovery
├── Events
├── Decoration
└── Validation
```

## Validate Map
Button:
`VALIDATE MAP`

Checks:

### Spawns
- Both teams represented
- Inside boundary
- Not inside geometry

### Objectives
- Required count exists
- IDs unique
- Reachable
- Inside boundary

### Pickups
- Reachable
- Inside boundary
- Metadata complete

### Launch Pads
- Target exists
- Arc clear
- Landing point inside boundary
- Landing point not a kill zone

### Geometry
- No gameplay object outside boundary
- No duplicate required IDs

### Sniper Perches
- Reachable
- Not inside spawn safety area

## Validation Output
Example:
```text
PASS: 6 Team A spawns
PASS: 6 Team B spawns
PASS: 3 objectives

WARNING: SniperPerch_02 has sightline toward Team B spawn

ERROR: SpeedPickup_03 outside playable boundary
ERROR: LaunchPad_01 has no target
```

## Bot Test Hook
Button:
`TEST WITH BOTS`

Initial behavior:
- Start Studio test
- Load current map
- Spawn 6v6 bots
- Run Convergence
- Output telemetry

Track:
- Stuck locations
- Spawn-to-objective time
- Objective participation
- Route usage
- Pickup usage
- Launch pad usage

## Designer Workflow
1. Greybox structure.
2. Place spawns.
3. Place objectives.
4. Place cover.
5. Validate.
6. Run bot test.
7. Fix flow/pathing.
8. Add pickups.
9. Validate again.
10. Human playtest.
11. Apply environment kit.
12. Add decoration/events.
13. Final validation.

## Ownership
Engineering:
- Plugin architecture
- Data schema
- Component registration
- Validation
- Bot hook

Design:
- Asset kit
- Layout
- Cover density
- Objective placement
- Theme
- Visual polish

Product:
- Gameplay requirements
- Mode rules
- Acceptance gates

## Acceptance Criteria
Pass when:
- Designer can open plugin.
- Structure placement works.
- Cover placement works.
- Spawns/objectives/pickups can be placed.
- Launch pads can be targeted.
- Grid snap works.
- Rotation/delete/duplicate work.
- Metadata is generated automatically.
- Map hierarchy stays organized.
- Validation catches missing/invalid components.
- Validation catches out-of-bounds objects.
- Basic bot test can be launched.
- No external editor is needed.
