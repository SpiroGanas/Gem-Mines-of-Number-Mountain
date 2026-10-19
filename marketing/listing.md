# Google Play store listing (P3-S26-01)

Source of truth for the listing text. Paste the two marked blocks into Play Console (Grow > Store presence > Main store listing). `tools/ci/test_listing.py` checks the limits and the content rules on every CI run: the short description is at most 80 characters, the full description at most 4,000, the required points are mentioned, nothing promises read-aloud or an AI voice (the app has neither; Spiro, 2026-10-19), and none of the family content rules' banned words appear.

Verify the current Play Console limits when pasting (they were 30 / 80 / 4,000 characters for title / short / full when this was written).

**App name (30 max):** Gem Mines of Number Mountain

## Short description

<!-- short:start -->
Dig for gems with Bolt the robot and grow real math skills. Offline, ad-free.
<!-- short:end -->

## Full description

<!-- full:start -->
Grab a pickaxe and join Bolt, a friendly mining robot, deep inside Number Mountain. Every rock you crack is a math puzzle. Solve it and a gem tumbles out!

Gem Mines of Number Mountain is a math adventure for children aged 6 to 12. It starts with counting and place value and climbs, one cave at a time, toward multiplication, factors and prime numbers.

FIVE ZONES TO EXPLORE
- Pebble Meadow: counting to 120, comparing, and tens and ones
- Quarry of Tens: adding and subtracting to 100, with regrouping
- Skip-Count Caves: counting by 2s, 5s and 10s, even and odd, first multiplying
- Factor Workshop: multiplication and division facts, factors and multiples
- Prime Caverns: prime numbers, divisibility rules, the sieve and factor trees

LEARNING THAT FITS YOUR CHILD
- The game notices what your child already knows and what needs more practice, and picks the next problem to match.
- Skills come back for review a day, a few days and a few weeks later, so they stick.
- Real math words, like "regrouping" and "prime", come with a picture and a kid-sized explanation, and are collected as Word Gems.
- Hints come one small step at a time.

KIND BY DESIGN
- Wrong answers never cost anything. "Not quite. Let's look again."
- No timers or countdowns, and no lost progress.
- Rewards are earned, never random. Rare gems come from rare numbers, like twin primes.

MAKE AND BUILD
Spend gems at the workshop to craft tools, build machines, decorate Bolt and fill a museum with gems and badges. Light an electric lantern for every day you play.

WRITE, TAP OR CLICK
Children can write their answers with a finger or a stylus on a touch screen, or use the big number pad. Everything also works with a mouse or a trackpad.

FOR GROWN-UPS
- A parent area, behind a grown-up question, shows a skill map and a weekly summary.
- Set the session length and family rewards.
- Up to four children can each have their own profile on one device.
- Move progress between your devices with a file you save and open yourself.

PRIVATE AND OFFLINE
- Works completely offline. The app does not ask for internet access.
- No ads. No in-app purchases. No accounts or sign-in.
- Nothing is collected about your child. Handwriting is read on the device and thrown away straight after.

Made for tablets and Chromebooks, in landscape.
<!-- full:end -->

## Content checks (done by hand, re-check when the text changes)

- Content rules (`CLAUDE.md`, "Content rules"): no alcohol, gambling, tobacco, smoke, campfires or fireplaces, bees, cats or dogs, octopus or shellfish. Light sources named are electric (the electric lantern). The automated banned-word check covers the words; a person checks the meaning.
- Tone: warm and encouraging; the feedback line quoted is the game's own ("Not quite. Let's look again.").
- Claims match the build: five zones (Zones 1-5, 72 skills), handwriting on touch screens only, mouse and trackpad support (the mouse-only path, Sprint 25), up to four profiles (Phase 3), export/import by file, no `INTERNET` (`tools/ci/check_manifest.py`). Phones are excluded, so the listing says tablets and Chromebooks.
- Not promised: read-aloud, narration or an AI voice (none in the app).

## Graphics

| Asset | Spec (verify current Play Console limits) | Source | Export |
|---|---|---|---|
| App icon | 512 x 512 PNG, 32-bit | `marketing/src/icon.svg` (code-drawn: a faceted gem lit by Bolt's headlamp) | `marketing/export/icon-512.png` |
| Feature graphic | 1024 x 500 PNG or JPEG, no transparency | `marketing/src/feature.svg` (the mountain in cross-section, one band per zone colour) | `marketing/export/feature-1024x500.png` |
| Tablet screenshots | at least 4; 16:10 and 16:9 | `tools/qa/capture_screens.tscn` (below) | `marketing/export/screenshots/` |
| Trailer (optional) | 30-60 s landscape video on YouTube | Screen capture of the emulator; the game's own music | not made yet |

The PNGs are rendered from the SVGs with `marketing/render.sh` (ImageMagick; see the script for the alternatives). The adaptive launcher icon layers in the export presets (`launcher_icons/*`) are still empty; that is an export-settings change for Spiro (432 x 432 foreground and background layers can be rendered from `icon.svg` the same way).

### Screenshot plan

`tools/qa/capture_screens.tscn` already captures every child screen at 16:9, 16:10, 3:2 and 4:3 with a demo save in a temporary folder (never the real save, never `private/`). For the listing:

1. Run it with a renderer (`xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 res://tools/qa/capture_screens.tscn`); it writes half-size JPEGs to `docs/qa/screens-1.0/`.
2. For store use, capture at full size (1920 x 1200 and 1920 x 1080) of these screens: the dig loop (mine with a rock and the answer panel), the chalk slate (a mine rock with the slate up), the museum, and the parent dashboard with a **fictional profile named "Sam"** (never Charlie's data). The dashboard and the slate are not in the tool's screen list yet; add them there rather than capturing by hand.
3. Save the chosen PNGs to `marketing/export/screenshots/` with the ratio in the name (`16x10-mine.png`).
