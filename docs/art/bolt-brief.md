# Art brief: Bolt, key art, zone banners and gems

> **Superseded (Sprint 20).** Spiro decided not to commission an artist. Version 1.0 uses Kenney CC0 packs and code-drawn art instead; `docs/art/asset-inventory.md` maps each item of this brief to what replaced it. The brief stays as a record in case a commission is reconsidered.

**Project:** Gem Mines of Number Mountain, a mining-and-crafting game that teaches number theory to children aged 6–12 on Android tablets and Chromebooks (landscape, touchscreen, stylus).
**Status:** draft for the Sprint 15 hand-off. Sending it to artists and recording a quote are human steps (`docs/development-plan.md`, sprint P2-S15-08). Nothing below has been agreed with an artist yet.
**Contact:** [fill in before sending]

## 1. What we need

| # | Deliverable | Notes |
|---|---|---|
| 1 | **Bolt**, the robot miner, in six poses | idle, point, cheer, think, "not quite" (gentle, encouraging), wave |
| 2 | **Bolt's headlamp as its own layer** | the game tints it to the color the child picks in Bolt's Garage (blue by default), so it must be separate and drawn in a neutral light tone |
| 3 | **Hub key art** | the workshop at the foot of Number Mountain, with the doors to the Mine, the Museum, the Garage and the (later) Build Site |
| 4 | **Zone banners, Zones 1–5** | Pebble Meadow, Quarry of Tens, Skip-Count Caves, Factor Workshop, Prime Caverns; each a wide strip used as a screen header and backdrop |
| 5 | **The gem set** | see section 4; gems differ by **shape as well as color** |
| 6 | **Rocks** (4 variations plus cracked states) | replaces the placeholder meteor sprites |

Later (not in this quote): Zones 6–12 banners, badge portraits of mathematicians, crafting and machine art.

## 2. The game in one paragraph

Charlie, a very curious six-year-old, and later other families' children dig through a mountain of numbers. Each rock holds a small problem. Solving it cracks the rock and a gem drops into the mine cart. Bolt, a small friendly robot with a headlamp, digs alongside, reads the problem aloud (text in a speech bubble for now) and encourages. Wrong answers cost nothing; Bolt just says "Not quite. Let's look again."

## 3. Bolt

- **Character:** a small, rounded robot on tracks with a headlamp on its head. Warm, curious, encouraging. Never mocks, sighs or is sarcastic; the "not quite" pose is a tilted head and an open, supportive gesture, never a slumped or sad one.
- **Silhouette first:** readable at 96 px tall on a tablet held at arm's length. Big eyes or a single expressive visor, simple hands (three fingers or a claw is fine).
- **Light:** **electric only**. The headlamp is an LED. No flames, torches or lanterns with fire, ever.
- **Layers:** body, arms, face/visor, tracks, headlamp (separate), headlamp beam (separate, soft, semi-transparent). Arms and face separate so we can animate them in the engine.
- **Poses:** each pose on the same canvas size with the same origin point (the contact point of the tracks on the ground) so poses can be swapped without the character jumping.
- **Reference:** the current placeholder is a Kenney robot sprite from a CC0 pack; it only shows the rough size and role.

## 4. Gems

Gems must be told apart by **shape**, not color alone (color-vision accessibility and rule 9 of the game: rarity comes from rare *numbers*, never chance).

| Gem | Where | Shape idea |
|---|---|---|
| quartz | common, Zone 1 | six-sided crystal point |
| garnet | Zone 2 | round cut |
| pyrite | Zone 3 | cube |
| amethyst | skill-mastery reward | tall prism |
| prime gem | Zone 4–5, a prime number | distinct and clearly "special" |
| twin gem | twin primes (p, p+2), drops as a linked pair | two joined gems |
| Mersenne gem | Mersenne primes (3, 7, 31, 127, 8191) | the rarest, legendary |
| square gem | perfect squares | square-faceted |
| six more museum minerals | the Gem Museum | malachite, fluorite, hematite, calcite, topaz, obsidian; the museum holds ten minerals in all (these six plus quartz, garnet, pyrite and amethyst above), each with a real mineral's look and its own outline |

Each gem as a flat sprite at 128×128 px (2×) with a transparent background, a 2 px dark navy outline, a simple highlight, and a "sparkle" variant (a separate layer) for the reveal.

## 5. Look and feel

- **Style:** flat, warm, slightly chunky vector-like shapes; clear dark outlines in navy `#1F2945`; soft gradients allowed. Friendly and bright, never scary: a mine is a cozy workshop, not a dungeon.
- **Palette anchors** (the game's UI already uses these; backdrops may be darker or lighter): navy `#1F2945`, lighter navy `#2E3C66`, off-white `#F5F7FF`, headlamp yellow, lavender `#C9B3F0`.
- **Contrast:** any text drawn over art must reach a contrast ratio of 4.5:1 or better; keep calm areas in the banners where the game places text.
- **Screens:** designed at 1920×1080 and scaled to 16:9, 16:10, 3:2 and 4:3. Keep the important content in the middle 80% and let the edges extend.

## 6. Content rules (from the game's family requirements; non-negotiable)

Never include, anywhere in any art:

- alcohol, gambling or gambling-like imagery (no slot-machine, card, dice or chest-of-chance looks), tobacco or smoking;
- **poor air quality**: campfires, fireplaces, smoky torches, smoke or steam effects, forges with smoke or steam; all light in the mine is **electric** (headlamp, electric lanterns, glowing crystals);
- bees, honeycomb or bee-like patterns; cats or dogs (no pet companions, no pet shapes hidden in the rocks);
- octopus or shellfish.

The tone is warm, curious and encouraging.

## 7. Formats and delivery

- **Layered source** in an open or widely-readable format (Krita `.kra`, `.psd` or `.ora`), one file per deliverable, layers named and grouped.
- **Exports:** PNG with transparency at **2× and 1×** (for example 1024×1024 and 512×512 for a gem sheet cell), sRGB. Pose and gem sheets as separate PNGs per item plus one packed sheet.
- **Naming:** `bolt_idle@2x.png`, `gem_quartz@2x.png`, `banner_z04_factor_workshop@2x.png`, lowercase with underscores. The game swaps sprites behind the same node names, so file names matter more than folder layout.
- **File budget:** the game download stays under 150 MB, all art included; keep each PNG under 1 MB where possible.

## 8. Rights and credits

- The game is intended for public release on Google Play (children's category), free updates thereafter.
- We need **full ownership or an unrestricted, perpetual license** for use in the game and its store listing, with the right to adapt colors (for example the headlamp tint).
- Each delivered file is listed in `assets/CREDITS.md` with its author and license; please say how you want to be credited.
- Please state which tools you use. **[Spiro to decide before sending: whether generative-AI tools are acceptable in the deliverables.]**

## 9. Process and timeline

1. Quote and timeline from you, for the six items above (one quote for items 1–2, another for 3–6 is fine).
2. A rough sketch round for Bolt (silhouette and three poses) before final art.
3. Delivery in two batches so integration can start early: Bolt and gems first; key art, banners and rocks second.
4. Integration is planned for Sprint 20 (late March 2027); the second batch is wanted by the start of that sprint.

## 10. Questions for the artist

- What do you need to know about the game to draw Bolt's six poses?
- Which of the deliverables do you want to be paid for per item, and which as a package?
- Do you have a preferred layered format?
