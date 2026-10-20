# Asset inventory for the Version 1.0 art and audio pass (Sprint 20)

Spiro decided not to commission an artist. The Version 1.0 look is built from **Kenney CC0 packs** plus the shapes the game already draws in code, and the music is **synthesized** by a project script. This page lists what was fetched in Sprint 20, where it came from, its licence, and which game element each file is for. Every file also has its own row in `assets/CREDITS.md` (the content lint's rule 10 checks that).

`docs/art/bolt-brief.md` (the Sprint 15 artist brief) stays as a record of what a commission would have covered; the table at the end maps each of its items to what replaces it.

## Where the files came from

All packs were downloaded from kenney.nl on 2026-10-17 (opengameart.org and itch.io are not reachable from the build environment). Every Kenney pack is **CC0 1.0** (public domain): no attribution is required, but the game credits it anyway. Each new folder carries the pack's own `License.txt`. Only the files listed here were copied; the zips stay outside the repository.

| Pack | URL | Used for |
|---|---|---|
| Particle Pack | https://kenney.nl/assets/particle-pack | Particle textures |
| Robot Pack | https://kenney.nl/assets/robot-pack | Bolt's extra frames (Bolt's body and tracks came from it in the Sprint 11 pass) |
| Platformer Art Deluxe | https://kenney.nl/assets/platformer-art-deluxe | Cave edges, stone tiles, counterweight, chain, signpost, ladder, plank |
| Platformer Pack Industrial | https://kenney.nl/assets/platformer-pack-industrial | Track segments, gear, electric lamps and beacons, control panel, scaffold, crate (the 140 px "Retina" files) |
| Game Icons and Game Icons Expansion | https://kenney.nl/assets/game-icons, https://kenney.nl/assets/game-icons-expansion | White glyphs, tinted in code like the four icons `IconArt` already uses |
| Impact Sounds, Interface Sounds, Music Jingles | https://kenney.nl/assets/impact-sounds, https://kenney.nl/assets/interface-sounds, https://kenney.nl/assets/music-jingles | Five new sound effects |

**Content rules checked.** Nothing fetched shows fire, torches, smoke, bees, cats or dogs, gambling, octopus or shellfish. The Particle Pack's fire, flame, smoke, scorch and muzzle textures were deliberately **not** copied; every light in the new files is electric (lamp posts, beacons, glows). The Robot Pack's "damage" and "hurt" frames were not copied either, because Bolt never looks hurt.

## Files and what each one is for

### Bolt (`assets/art/kenney/bolt/`)

The brief asked for six poses (idle, point, cheer, think, "not quite", wave). With CC0 frames and tweens:

| Pose | How it is made |
|---|---|
| Idle | `robot_body.png` + `robot_tracks.png` (existing) |
| Cheer | `robot_cheer.png` (the pack's jump frame: tracks tilted, a little hop) with a squash-and-stretch tween |
| Rolling (entering, leaving, wave) | `robot_drive1.png` / `robot_drive2.png` alternated, with `robot_tracks2.png` as the tracks' second frame; a wave is a side-to-side tween while rolling |
| Point | Idle body tilted toward the problem by a tween, with the headlamp beam drawn in code |
| Think | Idle body with `icons/question.png` in a small bubble |
| Not quite | Idle body with a slow gentle tilt (never a sad face; the pack's "hurt" frame is not used) |

The headlamp stays a separate layer drawn in code, so the Garage's colors keep working.

### Particles (`assets/art/kenney/particles/`), resized from 512 px

| File | Use |
|---|---|
| `sparkle.png` | Rock crack, celebrations |
| `glint.png` | A gem catching the light (rare gems especially) |
| `twinkle.png` | Word Gem card, badge earned |
| `glow.png` | Electric lantern, glowing crystals, a lit lamp |
| `halo.png` | Bolt's headlamp halo, lamp posts in the hub |
| `trail.png` | The gem's arc into the cart |

One `GPUParticles2D` per effect type, pooled (phase plan, Sprint 20 notes).

### Cave (`assets/art/kenney/cave/`), 70 px tiles

| File | Use |
|---|---|
| `stalactites.png`, `stalagmites.png` | Top and bottom edges of the mine backdrop and the zone banners |
| `stone_wall.png`, `stone_center.png` | Tiled mine backdrop, tinted per zone by `Backdrop.palette_for_zone` |
| `boulder.png` | Hub key art, build site dressing |
| `counterweight.png`, `chain.png`, `rope_vertical.png` | Balance-scale elevator build (Zone 3 to 4 gate) |
| `sign_post.png` | Zone banners (a signpost with the zone's name in Andika) and the Build Site door |
| `ladder.png` | Hub key art (the shaft down into the mountain) |
| `plank.png` | Cart track ties, workshop bench |

### Machines (`assets/art/kenney/machines/`), 140 px

| File | Use |
|---|---|
| `track_left.png`, `track_mid.png`, `track_right.png` | Cart track build (segments laid end to end) and the finished track animating in the hub |
| `gear.png` | Crafting bench, elevator winch, the Zone 4 (Factor Workshop) banner |
| `lamp_post_blue.png`, `lamp_post_yellow.png`, `lamp_post_green.png` | Electric lighting in the hub and the mine |
| `beacon_blue.png`, `beacon_green.png` | A machine running (blue) and a build finished (green) |
| `control_panel.png` | Elevator controls, crafting bench |
| `scaffold.png` | Elevator shaft, build site |
| `crate.png` | Workshop and build site supplies |

### Icons (`assets/art/kenney/icons/`), white glyphs tinted in code

| File | Use |
|---|---|
| `medal.png`, `medal_ribbon.png` | Mathematician badge emblems (one medal shape per badge, with the badge's own color and a code-drawn symbol: a sieve grid for Eratosthenes, a rectangle of dots for Euclid, a staircase sum for Gauss, a twin-prime pair for Sophie Germain). No portraits of real people are drawn |
| `trophy.png` | Badge case, Deep Dig |
| `star.png` | Challenge Door |
| `question.png` | Bolt's think pose |
| `checkmark.png` | Crafted, built, done |
| `export.png`, `import.png` | Parent area: move progress between devices |
| `information.png` | Word Gems glossary |
| `pencil.png`, `eraser.png` | Chalk slate |
| `flag.png` | Build Site door, a finished build |
| `key.png` | A zone that a build unlocks |

### Zone banners Z1-5

There is no banner art in any CC0 pack that fits, so each banner is composed in code: `sign_post.png` on a strip of `stone_wall.png` between `stalactites.png` and `stalagmites.png`, tinted with the zone's backdrop palette, with the zone's name from the text table and one prop: Z1 Pebble Meadow a few code-drawn pebbles, Z2 Quarry of Tens a ten-bar, Z3 Skip-Count Caves hopping marks, Z4 Factor Workshop `gear.png`, Z5 Prime Caverns code-drawn crystals with `glow.png`.

### Hub key art

Composed in code from the files above: the mountain backdrop, `ladder.png` down the shaft, `lamp_post_*` lights, Bolt, the finished machines (track, elevator) as they are built, and the existing code-drawn gems.

### Gem set

The gems stay **drawn in code** (`GemArt`): the rule that gems differ by shape as well as color rules out the Kenney gem sprites, which share one shape. `glint.png` and `glow.png` add the shine.

## Sound effects (`assets/sfx/kenney/`, moved there when they were wired in)

| File | When it plays | Source |
|---|---|---|
| `split.ogg` | A boulder splits (Zone 4 and 5) | Impact Sounds `impactMining_003.ogg` (softer than the crack sound, `impactMining_002`) |
| `sieve_mark.ogg` | A sieve cell is crossed out | Interface Sounds `scratch_003.ogg` (0.12 s, a soft chalk-like scratch) |
| `craft.ogg` | Crafting done | Interface Sounds `confirmation_003.ogg` |
| `build_step.ogg` | A build step clicks into place | Impact Sounds `impactMetal_light_004.ogg` (0.2 s) |
| `badge.ogg` | A mathematician badge earned | Music Jingles `jingles_STEEL04.ogg` (0.9 s steel-drum jingle, unlike the pizzicato wall-cleared fanfare) |

They were fetched into `assets/sfx/sprint20/` and moved into `assets/sfx/kenney/` when the game started using them (Sprint 20 integration); `SfxBank.SOUND_IDS` lists all seventeen.

## Music (`assets/music/placeholder/`)

All loops are synthesized by `tools/music/generate_placeholder_music.py` (no samples, deterministic) and loudness-normalized to -20 LUFS with ffmpeg's two-pass `loudnorm` (a single linear gain), so a cross-fade never jumps in volume. About 250 KB in all.

| File | Screen | Length | Character |
|---|---|---|---|
| `hub.ogg` | Workshop hub, museum, garage, settings | 26.7 s | Calm, 72 bpm (Sprint 10, regenerated at the new loudness) |
| `mine.ogg` | The mine in Zones 1-3 ("mine_z1_3") | 29.1 s | Calm, 66 bpm (Sprint 10, regenerated) |
| `mine_z4.ogg` | The mine in Zone 4, Factor Workshop | 27.4 s | A stepping mallet tune in D dorian, 70 bpm |
| `mine_z5.ogg` | The mine in Zone 5, Prime Caverns | 32.0 s | High bells that ring only on prime beats (2, 3, 5, 7, 11, 13), 60 bpm |
| `mine_z6.ogg` | The mine in Zone 6, Gear Works | 31.8 s | Two figures, one every 3 beats and one every 4, that meet on every 12th beat (their LCM), 68 bpm |
| `build.ogg` | Build site and crafting bench | 15.8 s | Short and bright, F major, 76 bpm |

## The artist brief's items and what replaces them

| Brief item (`docs/art/bolt-brief.md`) | Version 1.0 replacement |
|---|---|
| Bolt in six poses, separate headlamp layer | Robot Pack frames plus tweens (table above); headlamp drawn in code |
| Hub key art | Composed in code from cave and machine props |
| Zone banners Z1-5 | Composed in code: signpost, stone strip, zone prop |
| Gem set (shape and color) | Code-drawn `GemArt` (unchanged) plus glint and glow particles |
| Rocks | Space Shooter Extension meteors (Sprint 11, unchanged) |
| Mathematician badge portraits | Medal emblems with code-drawn math symbols; no portraits of real people |
