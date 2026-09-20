Yes. Since you declined the file handoff, here is the spec in a form you can paste directly to the engineer or into the repo as `SNOW_FORTRESS_MAP_SPEC.md`.

# Snow Fortress — Map Implementation Specification

**Approved amendment (2026-09-20):** Both sniper outposts must be two stories with protected upper firing rooms. Capture C moves to the fortress second floor. The second floor spans the full fortress footprint except access openings for the two existing stairs. This supersedes the minimal second-story/atrium scope below; other locked topology remains unchanged. Implemented revision: `sketch-graybox-v4`.

**Status:** Blockout Specification  
**Authority:** The provided map sketch is the authoritative reference for map topology.  
**Current phase:** Graybox / gameplay blockout only

## 1. Purpose

Rebuild **Snow Fortress** according to the approved player-designed layout.

The objective of this phase is **not to create a finished-looking map**. The objective is to reproduce the spatial relationships, traversal options, combat areas, and capture-point layout shown in the reference sketch so they can be tested before environmental work begins.

The sketch should be interpreted as a **topological specification, not merely inspiration**.

Do not independently redesign the map.

---

# 2. Core Layout

The map is organized around a **central Snow Fortress** with opposing teams spawning outside the fortress.

```text
                         NORTH

                  [ SNIPER OUTPOST ]

                      [ CAPTURE A ]

                           │
                           │
       ┌──────────────── SNOW ────────────────┐
       │               FORTRESS               │
       │                                      │
BLUE   │             [ CAPTURE C ]            │   RED
SPAWN  │                                      │  SPAWN
       └──────────────────────────────────────┘
                           │
                           │
                      [ CAPTURE B ]

                                      [ SNIPER OUTPOST ]

                         SOUTH
```

Blue approaches from the **west**.

Red approaches from the **east**.

Neither team begins in possession of the fortress.

The fortress and surrounding territory are contested space.

---

# 3. LOCKED Topology

The following elements are **locked** and should not be moved, removed, substantially altered, or replaced without explicit approval.

### Team spawns

**Blue Spawn**
- West side of map.
- Exterior to fortress.
- Should not begin inside a fortified defensive position.

**Red Spawn**
- East side of map.
- Exterior to fortress.
- Mirrors the general relationship Blue has with the fortress.

The intention is not necessarily pixel-perfect symmetry. Both teams should have reasonably comparable access to the primary combat areas.

---

# 4. Snow Fortress

The Snow Fortress is the dominant central structure and primary landmark.

It must support:

- Ground-level combat.
- Second-story combat.
- Multiple entrances.
- Vertical traversal.
- Fighting both inside and immediately outside the structure.

The fortress should **not function as one team's defensive base**.

Both teams are attacking contested territory.

The general footprint shown in the sketch should be maintained during the initial blockout.

---

# 5. Capture Points

There are three capture areas.

### Capture Point A

Located **north of the Snow Fortress**.

A should create combat outside the fortress rather than forcing every engagement into the central building.

### Capture Point B

Located **south of the Snow Fortress**.

Like A, this creates a distinct exterior combat district.

### Capture Point C

Located **centrally within/at the Snow Fortress**.

C represents the primary fortress combat area.

Exact capture-radius dimensions remain TBD during playtesting.

### Capture-point rule

Do **not** relocate A, B, or C simply to make implementation easier.

Their relationship should remain:

```text
        A

    FORTRESS
       C

        B
```

---

# 6. Sniper Outposts

Two dedicated sniper/high-ground positions are required.

### Northwest Outpost

Located northwest of the fortress.

### Southeast Outpost

Located southeast of the fortress.

These positions deliberately sit on opposing diagonals rather than simply being placed directly beside their respective team spawns.

The intention is to make them **contested secondary positions**, not permanent team-owned sniper nests.

Exact elevation and sightlines are TBD during blockout testing.

### Important

Neither sniper outpost should have an unrestricted firing lane directly into an enemy spawn.

---

# 7. Launch Pads

The map contains **four launch-pad approaches**.

### West / Blue side

Two launch pads provide movement toward the fortress:

- Northwest/west fortress approach.
- Southwest/west fortress approach.

### East / Red side

Two launch pads provide equivalent movement toward the fortress:

- Northeast/east fortress approach.
- Southeast/east fortress approach.

Their purpose is to create fast assault options in addition to conventional ground movement.

Launch pads should **supplement ground routes rather than become the only practical way to enter the fortress.**

Exact launch distance, velocity, trajectory, and landing position are TBD during blockout testing.

---

# 8. Ground Ramps / Fortress Access

The fortress must have conventional ground access.

The sketch identifies approximately four ramp/access locations around the fortress perimeter.

These should allow players to reach the fortress without requiring:

- Grappling.
- Ziplines.
- Launch pads.

Traversal mechanics provide tactical alternatives; they should not replace ordinary movement.

Ramp dimensions and precise positioning may be tuned during blockout, but the **multi-directional ground-access concept is locked**.

---

# 9. Ziplines

Two major zipline routes connect exterior positions to the fortress second story.

### Southwest Zipline

Runs from the **southwest exterior area toward the fortress second story**.

### Northeast Zipline

Runs from the **northeast exterior area toward the fortress second story**.

These routes create diagonal vertical attacks rather than simply duplicating the east-west ground assault.

**Both ziplines terminate at the fortress's second-story level.**

Do not convert them into ground-level transportation.

---

# 10. Sightline-Breaking Walls

The sketch includes walls near the southwest and northeast traversal areas.

These should initially be treated as **gameplay geometry**, not decoration.

Their intended function is to interrupt long sightlines and prevent exterior areas from becoming completely exposed shooting galleries.

Exact:

- height,
- length,
- orientation,
- thickness,

remain adjustable during blockout testing.

Do not remove them merely because the environment appears cleaner without them.

---

# 11. Second Story

The Snow Fortress requires a functional second story because the exterior ziplines terminate there.

The second-story interior is **not fully specified by the current sketch**.

Therefore:

**Do not invent a complex second-story layout yet.**

Create only enough blockout geometry to establish:

- zipline arrival locations,
- basic movement space,
- connection to the fortress,
- vertical relationship with the ground floor,
- preliminary firing positions.

The detailed second-story design should be reviewed separately.

---

# 12. What Is Locked vs. Tunable

## LOCKED

These require approval to change:

- Blue spawn west.
- Red spawn east.
- Central fortress.
- Capture A north.
- Capture B south.
- Capture C central/fortress.
- Northwest sniper outpost.
- Southeast sniper outpost.
- Four launch-pad approaches.
- Multiple conventional fortress entrances/ramps.
- Southwest → second-story zipline.
- Northeast → second-story zipline.
- Second-story fortress access.
- Sightline-breaking structures around the identified exterior areas.
- Fortress as contested territory.
- Neither team owns/defends the fortress at spawn.

## TBD / BLOCKOUT TUNING

Engineering may experiment with:

- Exact distances.
- Exact elevations.
- Fortress dimensions.
- Ramp slope.
- Corridor width.
- Cover dimensions.
- Launch velocity.
- Zipline speed.
- Spawn-to-objective travel time.
- Sightline length.
- Cover placement.
- Capture radius.
- Exact sniper-platform elevation.

These changes should improve the approved topology rather than alter it.

---

# 13. Blockout Requirements

The **first implementation must be graybox only**.

Use primitive Roblox geometry wherever practical.

Do **not** spend implementation time on:

- Snow effects.
- Detailed fortress models.
- Trees.
- Rocks for decoration.
- Icicles.
- Environmental storytelling.
- Finished textures.
- Detailed lighting.
- Decorative props.
- Particle effects.
- Cosmetic terrain work.

Gameplay geometry comes first.

An ugly map that plays correctly is the desired deliverable at this stage.

---

# 14. Required Blockout Review Images

Before additional environmental work, provide standardized screenshots.

### Screenshot 1 — Overhead

This is the most important.

Use approximately the **same orientation as the original sketch**:

```text
North
  ↑

Blue ← MAP → Red

  ↓
South
```

The overhead should clearly show:

- both spawns,
- fortress,
- A/B/C,
- both sniper outposts,
- all four launch pads,
- both ziplines,
- fortress approaches.

### Additional screenshots

Provide:

1. Blue Spawn → Fortress POV.
2. Red Spawn → Fortress POV.
3. Capture A POV.
4. Capture B POV.
5. Capture C POV.
6. Northwest Sniper Outpost POV.
7. Southeast Sniper Outpost POV.
8. Southwest Zipline approach.
9. Northeast Zipline approach.
10. Fortress second story.
11. Major ground entrances to fortress.

These screenshots become part of the design review.

---

# 15. Blockout Playtest

Once the geometry matches the sketch, test **gameplay rather than appearance**.

Evaluate:

### Navigation

Can a new player immediately understand:

- where the fortress is,
- where the major objectives are,
- how to reach the fortress,
- where alternative routes exist?

### Engagement timing

Measure:

- Blue spawn → A.
- Blue spawn → B.
- Blue spawn → C.
- Red spawn → A.
- Red spawn → B.
- Red spawn → C.
- Spawn → sniper position.
- Spawn → second story.

We should use actual gameplay results to establish final distances rather than guessing them in advance.

### Sightlines

Check whether:

- players can shoot directly into spawn,
- sniper outposts dominate excessive portions of the map,
- exterior approaches have adequate cover,
- fortress windows/openings create unfair firing lanes.

### Traversal

Test all:

- ramps,
- launch pads,
- ziplines,
- normal approaches.

The fastest traversal mechanic should not make every other route irrelevant.

---

# 16. Approval Gate

**STOP after the graybox playtest.**

Do not begin an environmental/art pass until the blockout has been explicitly approved.

Approval means:

1. Layout corresponds to the original sketch.
2. Major routes work.
3. Capture-point placement works.
4. Spawn relationships work.
5. Vertical traversal works.
6. Sniper positions work.
7. Sightlines are acceptable.
8. Engagement timing is acceptable.
9. Fortress interior/second story has been reviewed.

Only after approval should the map move to environmental production.

---

# 17. Change-Control Rule

This is particularly important.

If testing reveals that a major topology change may improve the map, **recommend the change rather than implementing it automatically**.

For example:

> "The northwest sniper outpost has too strong a sightline onto Capture C. Recommend moving it approximately 15 studs west or adding an additional sightline blocker."

Do not simply move it.

Likewise, do not:

- create new major routes,
- delete routes,
- move objectives,
- move spawns,
- relocate sniper outposts,
- remove traversal systems,
- substantially redesign the fortress,

without approval.

Small tuning changes to cover and geometry during blockout are expected.

**Topology changes require review.**

---

# 18. Map Development Workflow Going Forward

Snow Fortress should establish the workflow for future maps:

**1. Designer sketch**

↓

**2. Topology specification**

↓

**3. Engineering graybox**

↓

**4. Overhead comparison against sketch**

↓

**5. Gameplay playtest**

↓

**6. Geometry revisions**

↓

**7. Explicit blockout approval**

↓

**8. Environmental/art pass**

↓

**9. Final gameplay regression test**

The purpose of this workflow is to separate **map design decisions from map implementation decisions**.

The engineer should absolutely identify technical or gameplay problems and recommend improvements. But major spatial design changes should remain visible decisions rather than being introduced implicitly during implementation.

---

## Instruction I would send with it

> Build Snow Fortress as a graybox according to this specification and the attached sketch. The sketch is authoritative for topology. Do not attempt to improve or redesign the layout during this pass. Where dimensions or geometry aren't specified, make a reasonable blockout choice and identify it as a tuning decision. Stop after the graybox and required screenshots are complete. Do not begin the environmental/art pass until the blockout is approved.

That last instruction is important. **I would give the engineer both this spec and your original drawing**, because the drawing communicates spatial relationships better than another three pages of prose ever will.
