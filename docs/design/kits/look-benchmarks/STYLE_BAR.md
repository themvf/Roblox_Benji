# Kit look: the minimum bar

The user's direction (2026-11-17): BedWars kits are the **bare minimum** style for a kit
look. The nine screenshots here are that bar: Void Knight, Martin, Eldric, Arachne, Agni,
Dodo Whisper, Whisper, Zephyr, Warrior. Every kit look is reviewed beside two of them.

They are reference only. Nothing here is copied: no character, shape or texture from these
images goes into the game.

## What every one of them does

A kit look is not ready for review until its `look.json` says how it does each of these.
`python tools/kit_look.py review` refuses to run while any is empty.

1. **Outline.** Something leaves the body's box: horns, spikes, flames, fur, wings, a cape,
   a companion. Seen in silhouette at 50 studs, it is not a default avatar.
2. **Glow.** One loud accent colour, glowing, against a darker base: Void Knight's cyan
   veins, Eldric's green, Warrior's yellow orbs. One colour, not a rainbow.
3. **Texture.** Painted surfaces: gradients, worn edges, fur strands, rivets, cracks. No
   piece is a single flat colour.
4. **Proportions.** Exaggerated and uneven: oversized fists, shoulders and boots, a big
   head or helm, tapered and jagged plates. Nothing is an even bevelled box.

## What we learned getting here

- Box armour built from shapes, however detailed, reads as a prototype next to these.
- A generated piece fixed rigidly to one R15 body part keeps the detail and still animates;
  a generated whole-body statue tears at the joints (ninja-soldier-skins).
- Separate text prompts per piece drift apart in style. Pieces are made from crops of one
  approved concept sheet instead.
- The cheapest place to change a design is the concept picture, before any 3D exists.
