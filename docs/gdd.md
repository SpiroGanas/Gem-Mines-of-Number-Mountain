# Game design document

**Status:** v1, written in Phase 1, Sprint 2 (Nov 9–13, 2026). Reviewed by Spiro: _pending_. The math reviewer's sign-off on Zones 1–3 is tracked in section 9.

This document says **what the game is and how it should feel**. For *how it is built*, see `docs/phases/phase-1-ramp-up-to-mvp.md` (architecture and sprint backlog) and `docs/decisions.md`. For *why it exists* and the full 12-zone arc, see `docs/development-plan.md`. If this document and `CLAUDE.md` disagree, `CLAUDE.md` wins and this file gets fixed.

Contents: 1 Premise and tone · 2 Core loop · 3 Screens and flow · 4 Answer input · 5 Hints and feedback wording · 6 Rewards and guardrails · 7 Zone briefs · 8 Look and sound (placeholder direction) · 9 Playtests and reviews · 10 Game feel · 11 Open questions

---

## 1. Premise and tone

Charlie is the new apprentice at the Number Mountain mine. **Bolt**, a small mining robot with a headlamp, is his guide. The mountain has 12 zones, from the sunny **Pebble Meadow** at the top to the glowing **Infinite Core** at the bottom. Every rock holds a number problem. Cracking rocks drops gems into the mine cart, and gems pay for tools, Bolt's looks and a museum of real minerals.

**Who it is for.** The first player is Charlie, a gifted six-year-old who reads well. Later, other families' children aged 6–12. The MVP (Zones 1–3) is aimed at his weakest areas: place value and addition/subtraction.

### Tone

- **Warm, curious, encouraging.** Mistakes are information, not failure. The mountain is a place to explore.
- **Bolt never mocks, sighs, scolds or uses sarcasm.** Bolt is never impatient, and never says "Wrong!". When an answer misses, Bolt says **"Not quite. Let's look again."** (`bolt.feedback.not_quite`).
- **Real math words, always explained.** The first time a term appears, Bolt gives the kid-sized meaning ("When we swap ten ones for one ten, that's called **regrouping**."). Each term becomes a **Word Gem**: tap it any time for a picture and the definition (`curriculum/vocabulary.json`).
- **Reading level.** Written for a strong first-grade reader: sentences of 12 words or fewer, one instruction per line, a picture next to every instruction.

### Content guardrails (family requirements)

The family content rules in `CLAUDE.md` ("Content rules") apply to all art, text, story, examples, word problems and minerals. The list of excluded themes lives there, and `tools/ci/lint_content.py` scans text, curriculum, this document and asset names for them, so it is not repeated here. The design consequences: **all light in the mine is electric** (Bolt's headlamp, electric lanterns, glowing crystals), so the "lantern streak" is an electric lantern; Bolt has no animal companion; and examples, word problems and museum facts stay clear of the excluded themes.

### Bolt's voice

| Do | Don't |
|---|---|
| Short, friendly sentences. "Let's build it with tens and ones." | Long explanations, more than one instruction per line |
| Name what the child did well. "You traded ten ones for one ten." | Praise speed, luck or being "smart" |
| Invite another look. "Not quite. Let's look again." | "Wrong!", "No!", "Try harder", sighs, sarcasm |
| Say "we" for shared work. "Now we have two tens." | Talk down, or use baby talk |
| Use numbers as placeholders (`{n}`, `{a}`, `{b}`) | Hard-code a number into a line |

---

## 2. Core loop

One session is about **20 minutes** (a parent-set soft limit).

1. **Choose a dig.** Bolt suggests a tunnel (the adaptive engine picks it). The child can accept or go back to the hub.
2. **Dig.** A wall of **6–9 rocks** appears. The child taps a rock to select it.
3. **Read and answer.** The rock opens a problem in a panel: Bolt's speech bubble (the prompt), a picture (ten-frame, gem piles, number line, array), and the answer area (tap choices, drag targets or the number pad).
4. **Collect.** Correct answer: the rock wobbles, cracks and drops a **gem** into the **mine cart**; the coin counter ticks up. Not-quite answer: the rock gives a gentle wobble and the **hint ladder** starts (section 5). Nothing is ever lost.
5. **Repeat** until the wall is clear. Bolt then offers **"Head up to the surface"** or **"Dig more"**.
6. **Surface workshop (hub).** Spend coins in the Garage, visit the Gem Museum, check the lantern.
7. **Wind down.** At the session limit, Bolt says it is time to head up. The child can finish the current rock. A short recap shows skills practiced and gems earned. **No countdown is ever shown.**

The save happens after every rock (CLAUDE.md save points), so closing the app at any moment loses nothing.

### What makes a rock

| Rock stage | What the child sees |
|---|---|
| Idle | A rounded grey rock with its number-free outline. Larger than the 64 dp touch minimum. |
| Selected | Lifts slightly; its problem opens. |
| Wobble | Short rotation shake. Used for the first tap and for a not-quite answer. |
| Crack | Squash-and-stretch, a crack line, particles, the crack sound. |
| Gem drop | The zone's gem pops out and arcs into the cart. |

---

## 3. Screens and flow

```
Title ──► Hub (workshop) ──► Dig (mine) ──► Recap / wind-down ──► Hub
              │  ├─► Gem Museum
              │  ├─► Bolt's Garage (tools, headlamp colors)
              │  ├─► Settings
              │  └─► Grown-ups (parent gate ──► Parent area / dashboard)
Pause overlay (Escape or the pause button) is available over every screen except the parent area.
```

| Screen | Purpose | Notes |
|---|---|---|
| **Title** | Logo and one big Play button. | Placeholder text label until the logo exists (Sprint 10). |
| **Hub** | The surface workshop. Buttons: **Dig**, **Museum**, **Bolt's Garage**, **Settings**, **Grown-ups**. | Each button has a picture and a short label. Dig is the largest. |
| **Mine** | The dig loop in section 2. | Rock wall, problem panel, cart, Bolt's bubble. |
| **Museum** | One display case per mineral; a case opens when the child holds the gem. | 10 minerals in the MVP, a text fact each (Sprint 8). |
| **Garage** | Buy tools and Bolt's headlamp colors with coins. | Coins only. No real money, ever. |
| **Settings** | Sound volumes (Music, SFX), read-aloud toggle (stored now, used in Phase 3). | Session length lives in the parent area. |
| **Pause** | Resume, Hub, Settings. | Never shows a clock. |
| **Wind-down** | Bolt's goodbye and the recap. | Appears at the next rock boundary after the soft limit. |
| **Grown-ups** | Parent gate, then the dashboard (time played, mastered, struggling, settings, export/import). | The only place `LineEdit` is allowed. |

**Layout rules.** Landscape only; design for 16:9, 16:10, 3:2 and 4:3. Anchors and containers only, never absolute positions. Every interactive control is at least `UI.min_target_px()` (64 dp). No multi-finger gestures. Posture changes (laptop, tent, tablet) resize the window; the layout reflows and the game saves.

---

## 4. Answer input

Every problem declares which answer modes it accepts (`answer_modes` on the skill). The game picks the first mode the device supports. All modes work with **finger, stylus and mouse** and, where marked, the keyboard.

| Mode | How it works | Typical problems | Notes |
|---|---|---|---|
| **Tap** | Big choice buttons (2–4) or tap a picture (a pile of gems, a symbol). | Which is more, which symbol, which number comes next | Distractors come from named misconceptions. Choices are shuffled with the problem's seed. |
| **Drag** | Drag ten-bars and one-gems into slots; drag number tiles into a strip. | Build 34, trade ten ones for a ten, order three numbers | Uses `InputRouter` pointer events, not Godot's built-in drag and drop, so finger, pen and mouse behave identically. |
| **Number pad** | An on-screen pad: 0–9, backspace, a big Go button. | Write the numeral, sums and differences | **Never the system keyboard.** In laptop posture the keyboard's digits and Enter also drive it. |
| **Keyboard** | Typed digits and Enter, laptop posture only. | Same as number pad | Scholar mode later. |
| _Handwriting_ | Stylus or finger on the chalk slate. | — | Phase 2. Not in the MVP. |

Rules: **no `LineEdit` or `TextEdit` in any child-facing scene** (the tablet keyboard would pop up). Every mode must be completable on a mouse-only Chromebook.

---

## 5. Hints and feedback wording

### The hint ladder

A **not-quite** answer climbs one rung. Nothing is deducted.

| Rung | After | What happens |
|---|---|---|
| 1 | First not-quite answer | Bolt repeats the problem with the key words **highlighted**. |
| 2 | Second | A **visual model** appears (ten-frame, number line, gem piles, array). |
| 3 | Third | Bolt shows a **worked example** of a similar problem. |
| 4 | Fourth | The child gets an **easier problem of the same skill**. The skill is flagged for review and shown on the parent dashboard. |

Hint-assisted correct answers count as partial evidence for mastery. A recognized-but-rejected handwriting answer is never a wrong attempt (Phase 2).

### Feedback lines

| Situation | Bolt says | Line ID |
|---|---|---|
| Correct, first try | "That's it! Nice work." | `bolt.feedback.correct` |
| Correct after a hint | "You figured it out." | `bolt.feedback.correct_hint` |
| Not quite | "Not quite. Let's look again." | `bolt.feedback.not_quite` |
| Hint, rung 1 | "Here it is again. Look at these words." | `bolt.hint.look_again` |
| Hint, rung 2 | "A picture can help. Let's use it." | `bolt.hint.show_model` |
| Hint, rung 3 | "Let's try a friend of this problem." | `bolt.hint.worked_example` |
| Hint, rung 4 | "Let's try a smaller one first." | `bolt.hint.easier` |
| Targeted misconception hint | A line keyed to the distractor the child picked (for example `digit_swap`: "Check the order of your digits.") | `bolt.misconception.<name>` (added with each generator) |

Rules: feedback is about the **work**, not the child. Never "Wrong!". Never praise speed. No sound effect is harsh or sad; a not-quite answer gets a soft, neutral wobble sound.

---

## 6. Rewards and guardrails

Rewards v1 (built in Sprint 8):

| Reward | How it works |
|---|---|
| **Coins** | 1 per cracked rock, 2 for a first-try answer. |
| **Gems** | One per cracked rock, of the zone's type: **quartz** (Zone 1), **garnet** (Zone 2), **pyrite** (Zone 3). Mastering a skill drops a bonus **amethyst**. |
| **Gem Museum** | 10 minerals with a text fact each: quartz, garnet, pyrite, amethyst, malachite, fluorite, hematite, calcite, topaz, obsidian. A case opens when the child holds that gem. Facts follow the content rules in section 1. |
| **Tools** | `pickaxe_t1` (start) and `pickaxe_t2` (50 coins; a bigger crack effect). |
| **Bolt customization** | Headlamp colors: blue (default), green (20 coins), gold (40 coins). |
| **Lantern streak** | An electric lantern lights for every calendar day with at least one cracked rock. **Missed days pause the streak; it never resets.** |

### Guardrails (non-negotiable)

1. **Wrong answers never cost anything.** No lost gems, no game-over, no streak reset.
2. **No timers or countdowns** in Explorer mode. The session limit is a soft wind-down, not a clock.
3. **Rewards are earned and deterministic.** No loot boxes, spinners or slot-machine reveals. Rare gems (later zones) come from rare *numbers*, such as twin primes and Mersenne primes.
4. **No purchases** of any kind in the game.
5. **No speed rewards.** Latency is used only by the hidden fluency check for math-fact skills and is never shown to the child.
6. **No "come back now" pressure** and no notifications.

---

## 7. Zone briefs

Skill counts are for the shipped skill map (`curriculum/skills/`). Skill IDs, prerequisites and the generator for each skill are defined there.

### Zone 1: Pebble Meadow (17 skills)

- **Math.** Counting to 120; comparing with <, > and =; place value with one-gems, ten-bars and a hundred-block; regrouping ("trade ten"); writing numerals.
- **Why first.** It targets Charlie's weakest area (Number & Operations in Base Ten) and the place-value language every later zone uses.
- **Path through the zone.** counting → comparing → build/read/expand tens and ones → trade ten ones for a ten and back → ten more/less → the first hundred.
- **Concrete → pictorial → abstract.** Rocks first show gems, bars and number lines; later the same idea appears as a bare numeral.
- **Mineral.** Quartz. **Engineering tie-in.** Loading carts to their capacity. **Science.** What a mineral is.
- **Signature moment.** Trading ten one-gems for a ten-bar: the gems slide together and become one bar. The paper prototype (section 9) tests whether "trade ten" makes sense before this is built.

### Zone 2: Quarry of Tens (17 skills)

- **Math.** Add and subtract within 20, then within 100 with regrouping; fact families; inverse operations; the equals sign as a balance; missing addends; adding three numbers.
- **Path.** facts within 10 → make a ten → within 20 → fact families and missing numbers → tens → within 100 without, then with, regrouping.
- **Mineral.** Garnet. **Engineering tie-in.** Balance-scale cart loading; track lengths.
- **Key picture.** Ten-frames for "make a ten"; a balance scale for equations.

### Zone 3: Skip-Count Caves (11 skills)

- **Math.** Skip counting by 10, 5 and 2; even and odd; arrays (rows and columns); repeated addition becomes multiplication; equal groups; the commutative property; the 2, 5 and 10 times tables.
- **Path.** skip counting → even/odd by pairing → arrays → repeated addition → equal groups → commutative matching → facts.
- **Mineral.** Pyrite (which really forms cubes). **Engineering tie-in.** Conveyor belts carrying equal groups.
- **Key picture.** Arrays of gems on the conveyor; pairs for even and odd.

### Zones 4–12 (outlined; built after the MVP)

| # | Zone | Math focus | Skills outlined |
|---|---|---|---|
| 4 | Factor Workshop | Multiplication and division facts, factors, multiples, prime vs. composite | 15 |
| 5 | Prime Caverns | Sieve of Eratosthenes, prime factorization, divisibility rules | 11 |
| 6 | Gear Works | GCF, LCM, simplest form, gear ratios | 12 |
| 7 | Crystal Shards | Fractions, decimals, percents, ratio, negative numbers | 20 |
| 8 | Power Tower | Exponents, roots, binary and other bases, scientific notation | 16 |
| 9 | Pattern Grotto | Sequences, triangular and Fibonacci numbers, Gauss's sum | 15 |
| 10 | Clockwork Depths | Modular arithmetic, congruence, groups | 15 |
| 11 | Cipher Vault | Caesar and affine ciphers, modular inverses, Euclid, toy RSA | 15 |
| 12 | The Infinite Core | Proof, irrational numbers, famous open problems | 11 |

Detailed prerequisites for each zone are written when its sprint begins (Zones 4–5 in Phase 2; later zones in Phases 4–5).

---

## 8. Look and sound (placeholder direction)

The MVP uses **placeholder art** that is coherent, not final. Commissioned art (Bolt and key art) is Phase 2.

### Visual direction

- **Style:** flat, chunky, high-contrast shapes with soft rounded corners. One consistent light direction. Nothing busy behind text.
- **Palette:** deep blue-navy mine background (`#1F2945`), warm yellow headlamp glow, saturated gems, off-white panels with dark text. Contrast between text and its background must meet WCAG AA.
- **Gems differ by shape as well as color** (color is never the only clue):

  | Gem | Zone | Shape | Color |
  |---|---|---|---|
  | Quartz | 1 | Six-sided crystal point | Clear light blue |
  | Garnet | 2 | Round-cut stone | Deep red |
  | Pyrite | 3 | Cube | Gold |
  | Amethyst (mastery bonus) | any | Tall prism | Purple |

  The museum minerals (calcite, topaz, malachite, fluorite, hematite, obsidian) follow the same rule; their shapes and colors live in `scenes/mine/gem_art.gd`.

- **Bolt (placeholder):** a rounded grey-blue robot with a lamp on its head and two simple eyes. Expressions: neutral, happy, thinking. No mouth movement is needed in the text-only MVP.
- **Typography:** **Andika** (SIL Open Font License), a font designed for early readers, at large sizes. Selected; import is pending Spiro's approval in `docs/sdk-audit.md` (see section 11). Until it is imported the engine's default font is used.

### Asset sources (see `assets/CREDITS.md`)

- Third-party placeholder art and sound come only from **CC0** sources (Kenney's packs are CC0). Every file gets a credits entry before it is committed.
- Until the CC0 import, gray-box shapes and SFX are **project-made** (drawn in SVG, synthesized by a script in `tools/`).

### Audio direction

- **Every action has a sound** (tap, select, wobble, crack, gem, coin, button). Sounds are short, soft and never startling; a not-quite answer gets a gentle neutral wobble, never a buzzer.
- Buses: `Music`, `SFX`, `Voice` (voice is empty until Phase 3). Format: OGG.
- Music (Sprint 10): calm, looping, low-key; never urgent.

---

## 9. Playtests and reviews

These are human steps. **Status: not yet run.** Record results here.

### 9.1 Math reviewer sign-off (Zones 1–3)

The math reviewer checks `curriculum/skills/z01_*.json`, `z02_*.json` and `z03_*.json`: order of skills, prerequisites, grade-appropriateness, the named misconceptions in `curriculum/misconceptions.json`, and the Word Gem definitions in `text/lines.csv` (`vocab.*`). Changes to prerequisites need Spiro's sign-off and a note in `docs/decisions.md`.

| Reviewer | Date | Zones | Result | Notes |
|---|---|---|---|---|
| _pending_ | | 1–3 | | |

### 9.2 Paper prototype with Charlie (P1-S02-05)

**Question:** does "trade ten" make sense to Charlie? **Time:** about 20 minutes, seated at a table, no screens.

**Materials.**
- Paper "rocks" (cut-out rounded shapes), each with a number written on the back: 14, 23, 34, 41, 56, 13, 17.
- Lego bricks: a **ten-bar** is one 1×10 row or ten studs fixed together (for example five 2-stud plates); a **one-gem** is a single small brick. Include about 25 loose one-gems and 8 ten-bars.
- A "cart" (a shoebox or tray) for collecting.

**Script.** Say each prompt in your own words. Do not correct him; ask "How do you know?" and watch.

1. _Build._ Turn over the rock showing 34. "Fill the cart with 34. You may use bars and gems." Watch: does he use bars, or count 34 single gems?
2. _Read._ Put 2 bars and 7 gems in the cart. "How many is that?" Watch: does he say 27, 9, or count the bars as ones?
3. _Trade._ Give him 13 loose gems. "Can you swap some of these to make fewer pieces?" Watch: does he find the trade without prompting, and say "ten" for the bar?
4. _Untrade._ Give him 2 bars and 0 gems. "Take 5 away." Watch: does he break a bar into ten gems? Does he say it out loud?
5. _Ten more._ "Here is 34 again. Add one more bar. How many now?" Watch: does he count on by tens?
6. _Words._ Say "tens", "ones", "regrouping", "digit". Ask which ones he knows. Note any word he uses a different way.

**Notes template (fill in after the session).**

| Item | Observation | Words that confused him | Change to the game |
|---|---|---|---|
| Build 34 | | | |
| Read 2 bars + 7 gems | | | |
| Trade 13 | | | |
| Untrade | | | |
| Ten more | | | |
| Words | | | |

_Date run:_ ______ · _Present:_ ______ · _Decision:_ keep "trade ten" wording / change to ______.

### 9.3 Sprint 4 "Is digging fun?" test

Run the gray-box dig loop with Charlie over Thanksgiving weekend (Nov 26–29). If the loop is not fun with plain shapes, **fix the loop before adding content** (Sprint 5 then starts with loop fixes).

Watch for: does he want to dig *one more rock*? Does the crack and gem drop feel satisfying? Does he understand what to do without help? Are the drag targets big enough? Does the not-quite wobble feel gentle?

| Question | Observation |
|---|---|
| Asked to keep digging? | |
| Needed help to start? | |
| Favorite moment | |
| Frustrating moment | |
| Loop changes to make | |

---

## 10. Game feel

Principles the dig loop follows (the Sprint 1 study of game-feel patterns; Spiro adds his own notes below):

1. **Every input gets an immediate response**, within a frame: a press highlight, a sound, a small motion.
2. **Squash and stretch** on anything that cracks, lands or pops. Short and elastic (about 100–250 ms), then settle.
3. **Anticipation, action, reaction.** The wobble (anticipation) comes before the crack (action); the gem arc and cart bounce (reaction) follow.
4. **Particles and a sound on every meaningful moment**: crack, gem, coin, a new tool.
5. **Reward the work, not the clock.** Celebrations mark mastery and finishing a wall, never speed or luck.
6. **Calm baseline.** No constant flashing or looping motion; the screen is quiet while the child thinks.

_Spiro's notes from the game-feel study (P1-S01-03):_ _(to be added)_

---

## 11. Open questions

| Question | Owner | When needed |
|---|---|---|
| Approve Andika (SIL OFL) in `docs/sdk-audit.md` and import it into `assets/fonts/` | Spiro | Before Sprint 7 (Explorer theme) |
| Confirm the Kenney (CC0) packs to import for rocks, gems, UI and sound, then credit each file | Spiro | Sprint 10 art pass |
| Paper prototype results and the "trade ten" wording | Spiro and Charlie | Before the Zone 1 lines are final (Sprint 5–7) |
| Math reviewer for Zones 1–3 | Spiro | Before Sprint 6 (the engine consumes the prerequisites) |
| Pen as touch for all MVP interactions (recommended) vs. separate pen handling | Spiro | After the Sprint 1 device test |

---

## 12. Readability checklist (P1-S10-04)

Run this on every screen before it ships, and again after any layout change. The automated half runs in `tests/scenes/test_readability.gd` on every screen the Shell can show; the rest is a manual check with the screenshots on the 2-in-1 and the tablet.

| # | Check | How it is checked |
|---|---|---|
| 1 | Every button is at least one touch target (`UI.min_target_px()`, 64 dp) in both directions | Automated |
| 2 | Every visible word comes from `text/lines.csv`: no `[missing.id]`, no unfilled `{placeholder}` | Automated, plus `tools/ci/lint_content.py` |
| 3 | No `LineEdit`, `TextEdit` or `SpinBox` outside the parent area | Automated, plus the lint |
| 4 | Text on every backdrop palette keeps AAA contrast (7:1); button text keeps AA (4.5:1) | Automated (`test_readability.gd`, `test_explorer_theme.gd`) |
| 5 | Every workshop button has a picture as well as a word | Automated |
| 6 | Every instruction has a picture beside it (the problem's visual, a pile, a strip or an icon) | Manual |
| 7 | Color is never the only clue: gems differ by shape, the lantern shows a bulb, choices carry words or numbers | Manual (gem shapes are also checked in `test_gem_art.gd`) |
| 8 | Nothing is cut off at 16:9, 16:10, 3:2 and 4:3, with the longest hint (rung 3) on screen | Manual, with the screenshot probe; Bolt's notes are capped at two lines |
| 9 | Overlays (Word Gem card, celebration, wind-down) cover the whole screen and wait for a tap | Automated (`test_mine.gd`) and manual |
| 10 | Each Explorer line is one instruction of 12 words or fewer | Lint warning, plus a read-through |

**Last run:** Sprint 10, at 1920×1080, every screen and one problem of each input kind with hint rungs 1–3. Fixed: the rung-3 build board was pushed off the screen (Done now sits beside the piles and the notes are capped at two lines), Bolt was drawn stretched beside a tall bubble, the tile strip's worked example needed the room taken by the picture, and the three overlays were drawn in the top-left corner instead of filling the screen. Still to do on the devices: the same pass at 4:3 and 3:2, and with the stylus.
