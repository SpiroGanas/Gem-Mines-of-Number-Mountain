# Gem Mines of Number Mountain: Software Development Plan

**Prepared for:** Charlie (age 6, Grade 1) and family
**Plan date:** October 15, 2026
**Plan version:** 2.1. Version 2.0 covered the self-built game, the ARM 2-in-1 Chromebook with stylus, a new Android tablet and a publish-ready design. Version 2.1 moves AI-voice narration out of the MVP to Phase 3, because Charlie reads well.

## Key facts at a glance

| Item | Answer |
|---|---|
| Developer | **Spiro** (MS in CS, Georgia Tech; AI expert; new to game development), full time (~40 hrs/week), using an AI coding assistant |
| Charlie's devices | **New 2-in-1 Chromebook** (modern ARM chip, touchscreen, stylus) and a **new Android tablet**. The old non-touch Chromebook is retired. |
| Other devices supported | Other families' Chromebooks and tablets (ARM and Intel/AMD, touch or mouse-only). Phones are out of scope. |
| Engine | **Godot 4.7.x** (GDScript), exported as an Android app, plus a small **Kotlin** Android plugin for handwriting recognition |
| Voice | **Licensed AI voice narration**, generated ahead of time as audio files (no live AI in the game). **Added in Phase 3 (Sprint 22), after the MVP.** The MVP is text-based, since Charlie reads well. |
| Distribution | Google Play: private testing first, then a **public release** built for Google Play's rules on children's apps |
| Sprint length | 1 week. Sprint 1 starts **Monday, November 2, 2026**, with a 2-week holiday break Dec 21 – Jan 1. |
| **MVP** | **End of Sprint 11: Friday, January 29, 2027** |
| Budget approach | **MVP first, then decide.** Sprints 12–52 are a provisional roadmap, confirmed at the decision gate (Feb 19, 2027). |
| Version 1.0 (Zones 1–5, handwriting, cross-device progress) | End of Sprint 21: April 9, 2027 (private) |
| Public launch on Google Play | End of Sprint 28: about May 28, 2027, plus Google's review time |
| Full game (all 12 zones) | End of Sprint 52: November 12, 2027 |

### What changed from version 1.0 of this plan

| Area | Change |
|---|---|
| Team | Spiro builds the game instead of a hired developer. Sprint 1 now includes Godot ramp-up, and the MVP moves to Sprint 11 (11 working sprints). |
| Start date | Moved up to Nov 2, 2026 (no hiring delay), so the MVP lands about 6 weeks earlier than before (Jan 29 vs. Mar 12). |
| Devices | Both of Charlie's devices are touch-first and ARM-based. Touch, stylus and tablet mode now come first, and the mouse becomes secondary. |
| Stylus | New **handwritten-answer** feature (Sprints 13–14). Charlie writes numbers with the pen or a finger, which doubles as handwriting practice. |
| Voice | A licensed AI voice replaces the voice actor, and a scripted pipeline generates all narration audio. **(v2.1)** Narration moves out of the MVP to Sprint 22, since Charlie reads well. The MVP uses kid-friendly on-screen text instead, and later sprints shift by one week. |
| Adaptive engine | Uses **Bayesian Knowledge Tracing** (a standard learning-science model), which plays to Spiro's AI background. |
| Publishing | New **Phase 3: Public release readiness** (Sprints 22–28): AI-voice narration, child profiles, Families Policy compliance, privacy policy, store listing, closed test. |
| Budget | Spiro's own time plus small cash costs. Commit to the MVP first. |

---

## 1. Summary

*Gem Mines of Number Mountain* is a mining-and-crafting adventure that teaches number theory, from counting and place value at age 6 to modular arithmetic, cryptography and proof by age 12. Charlie digs into a mountain where every rock is a number:

- **Prime numbers are unbreakable gems.**
- **Composite boulders** break apart when he finds their factors.
- Gems he collects pay for tools, machines and a museum of real minerals.

Deeper parts of the mountain hold harder math, and the game's adaptive engine decides when he's ready to go deeper. That pace comes from his own performance, not his grade level.

The plan has **52 one-week sprints in five phases**. The **minimum viable product (MVP)** is ready at the **end of Sprint 11 (January 29, 2027)**. At that point Charlie can play an adaptive, text-based game covering place value, addition and subtraction, skip counting and early multiplication, on both his 2-in-1 Chromebook and his tablet. Three weeks of real play then feed a **go/no-go decision** (February 19, 2027) before committing to the rest.

Two things about Charlie shape the MVP:

1. **The MVP is text-based.** Charlie reads well, so on-screen text carries the instructions, using a large, clear font and short sentences. **AI-voice narration is added in Phase 3 (Sprint 22),** mainly for younger and non-reading players in other families. All text lives in one table from day one, so adding narration later doesn't mean reworking screens.
2. **The first zones go deep on place value and addition/subtraction.** His thinnest Star Math areas in September were Number & Operations in Base Ten (40%) and Operations & Algebraic Thinking (49%).

The stylus adds a third benefit: writing digits by hand builds the handwriting skills first grade is working on.

---

## 2. Game overview

### 2.1 Premise

Charlie is the new apprentice at the Number Mountain mine. His guide is **Bolt**, a small mining robot with a headlamp who gives instructions in short speech bubbles (and speaks them aloud once narration arrives in Phase 3). The mountain has 12 zones stacked from the sunny meadow at the top to the glowing Infinite Core at the bottom. Each zone is a new kind of math, and each has its own mine-engineering projects (cart tracks, elevators, gear machines, vault locks).

### 2.2 Core gameplay loop (one session of about 20 minutes)

1. **Choose a dig.** Bolt suggests a tunnel. The adaptive engine picks it, mixing about 70% new-skill practice with 30% review.
2. **Dig.** A rock wall appears, and each rock holds a challenge. Examples by stage:
   - **Early:** "This rock is worth 34. Load 3 ten-bars and 4 one-gems into the cart."
   - **Later:** "Split 36 into two factors" (drag the pickaxe to 4 × 9), or "Which of these are unbreakable?" (primes).
3. **Answer** in whichever way suits the problem and the device:
   - **Tap or drag** gems, bars and pickaxe splits.
   - **Write the number** with the stylus or a finger on a chalk slate (from Sprint 14).
   - **Use the in-game number pad**, which avoids the system keyboard popping up in tablet mode.
   - **Use the keyboard** in laptop mode (Scholar mode).
4. **Collect.** Correct answers crack rocks open and drop gems into the mine cart. Wrong answers make the rock wobble, and a hint ladder starts (see 3.4). There's never a game-over.
5. **Return to the surface workshop.** Gems become coins, crafting materials and museum pieces. Crafting recipes are math too (for example, "3 garnets × 4 = enough for a lantern upgrade").
6. **Build.** Between zones, Charlie completes a mine-engineering project that unlocks the next zone. Examples: a cart track, a counterweight elevator, a gear-driven conveyor.
7. **Wind down.** At the session time limit, Bolt says it's time to "head up to the surface." A short recap shows what Charlie learned and what he earned.

### 2.3 The 12 zones

The ages are only rough guides. The adaptive engine moves Charlie as fast as his mastery allows. The game uses real math terms, each with a spoken, kid-sized explanation.

| # | Zone | Math (with real terms) | Engineering / science tie-in | Rough age |
|---|---|---|---|---|
| 1 | **Pebble Meadow** | Counting to 120; comparing (<, >, =); **place value** with one-gems, ten-bars and hundred-blocks; **regrouping** ("trade ten"); writing numerals | Loading carts to capacity. Science: what a mineral is. | 6 |
| 2 | **Quarry of Tens** | Addition and subtraction within 20, then within 100 with regrouping; **fact families**; **inverse operations**; the equals sign as balance | Balance-scale cart loading; track lengths | 6–7 |
| 3 | **Skip-Count Caves** | Skip counting; **even and odd**; **arrays**; repeated addition becomes **multiplication**; **commutative property** | Conveyor belts carrying equal groups | 6–7 |
| 4 | **Factor Workshop** | Multiplication and division facts; **factors**, **multiples**, **factor pairs** as rectangles; **prime** vs. **composite** | Support beams arranged in rectangles; which shapes are strongest | 7–8 |
| 5 | **Prime Caverns** | **Sieve of Eratosthenes**; **prime factorization** (factor trees); **Fundamental Theorem of Arithmetic**; divisibility rules | Crystal structures; real minerals in the Gem Museum | 7–9 |
| 6 | **Gear Works** | **Greatest common factor (GCF)**, **least common multiple (LCM)**; **simplest form**; gear ratios | Gear trains that sync up; designing machine speeds | 8–9 |
| 7 | **Crystal Shards** | Fractions: **equivalent fractions**, comparing, adding; decimals; percents; **ratio**; **negative numbers** (depth below the mountain's base) | Mixing ore alloys by ratio; depth gauge | 8–10 |
| 8 | **Power Tower** | **Exponents**, square and cube numbers, **square roots**; powers of 2 and 10; **binary** and other bases; **scientific notation** | Elevator floors; lever counterweights | 9–10 |
| 9 | **Pattern Grotto** | Sequences; **triangular** and square numbers; **Fibonacci** numbers and the **golden ratio**; Gauss's sum 1 + 2 + … + n; **proof without words** | Crystal growth and spirals. Poetry: Fibonacci "Fib" poems | 9–11 |
| 10 | **Clockwork Depths** | **Modular arithmetic**, **congruence** (a ≡ b mod n), remainders; **cyclic groups** ℤₙ with **identity**, **inverse** and **closure**; why divisibility rules work | Rotating vault locks; gear clocks | 10–11 |
| 11 | **Cipher Vault** | Caesar and **affine ciphers**; **modular inverses**; **Euclidean algorithm** (basic and extended); **Diophantine equations**; the idea behind **RSA** with small primes | Designing secure vault doors | 11–12 |
| 12 | **The Infinite Core** | **Proof**: infinitely many primes (Euclid); √2 is **irrational**; integers, rationals, reals; famous **open problems** (Goldbach, twin primes) | "Mathematician's Journal" for building proofs with drag tiles | 11–12+ |

Zone 10 is where the abstract algebra you asked for first appears. Charlie learns that the clock numbers ℤₙ form a **group**, using the same vocabulary a college course would.

---

## 3. Learning design

### 3.1 Skill map

The curriculum is a **directed graph of about 180 skills** (nodes) with prerequisite links (edges). Each skill record holds:

- **ID and prerequisites:** for example, `pv.tens_ones.build` requires `count.to_100`.
- **Problem generator:** creates unlimited fresh problems from parameters. No problem bank is needed.
- **Three representations**, following the concrete → pictorial → abstract approach: gems and bars, then drawings and number lines, then symbols. Mastery at one level unlocks the next.
- **Common-misconception distractors:** for example, answering 43 when the answer is 34, or adding the tens digits but forgetting the regrouped ten.
- **Vocabulary terms:** spoken kid-friendly definitions, collected as "Word Gems" in a glossary.
- **Text templates:** the problem text, with placeholders for numbers. The same templates drive narration from Phase 3.
- **Allowed answer modes:** tap, drag, handwriting, number pad or keyboard.

### 3.2 Adaptive engine

**Model: Bayesian Knowledge Tracing (BKT), one model per skill.** BKT estimates the probability that Charlie has learned a skill, updating after each answer using four parameters: prior knowledge, learning rate, guess and slip. It's interpretable, light enough to run on the device, and well studied in tutoring systems.

- **Mastery:** P(learned) ≥ 0.95, **and** correct answers on at least 2 different days, so one lucky streak doesn't count. For math-fact skills there's also a gentle fluency check (median response time). Speed is never shown to Charlie as pressure.
- **Parameters:** start with literature-typical defaults per skill type. After the MVP, fit them from Charlie's exported play logs (expectation-maximization), done offline on Spiro's computer, never in the app.
- **Hint use** counts as partial evidence, and a handwriting answer the recognizer was unsure of doesn't count against him (see 3.6).
- **Frontier:** the engine only offers skills whose prerequisites are mastered, and it interleaves 2–3 frontier skills rather than drilling one.
- **Spaced review:** mastered skills come back after 1, 3, 7, 21 and 60 days. About 30% of each session is review, and a forgotten skill drops back to practice.
- **Acceleration ("Challenge Door"):** Charlie can test out of a skill by solving 3 of 3 harder problems. This is how the game supports a gifted pace.
- **Placement quest:** a 10-minute "survey the mountain" adventure that finds the starting point. For Charlie it's seeded from his Star results (start at Zones 1–2). For other families, a parent picks a starting grade and the quest adjusts from there.
- **Simulated learners:** automated tests run computer-simulated players (fast, average, slow, random guesser) through the engine. A random guesser must never master anything, and a fast learner must be able to test out quickly.

### 3.3 Two interface modes

- **Explorer mode (default for ages 5–8):** large, clear text in short sentences, pictures first, and answers by tap, drag or handwriting. From Phase 3, a **read-aloud** setting adds narration with word highlighting. It's on by default for younger or non-reading profiles and optional for Charlie.
- **Scholar mode (unlocks gradually, roughly age 9+):** more on-screen text, keyboard or number-pad entry, real notation (exponents, ≡, fractions) and less narration.

The switch happens per feature, based on reading checks and a parent setting, so there's no sudden jump.

### 3.4 Hint ladder (when a rock "wobbles")

1. **First wrong answer:** Bolt shows the problem again with key words highlighted (and reads it aloud when read-aloud is on).
2. **Second:** a visual model appears (ten-frame, number line, array).
3. **Third:** Bolt shows a worked example of a similar problem.
4. **Then:** an easier version of the same skill. The skill gets flagged for review, and the parent dashboard notes it.

### 3.5 Session and data rules

- Sessions have a **soft limit set by the parent** (default 20 minutes) with a wind-down instead of a hard cutoff.
- **All learning data stays on the device.** There are no ads, no purchases inside the game, no third-party analytics and no live AI calls.

### 3.6 Handwritten answers (stylus or finger)

- **Chalk slate:** a large writing area with guide lines. Charlie writes one digit per box, and multi-digit numbers use one box per digit. That makes recognition much more reliable and reinforces place value (tens box, ones box).
- **Recognition:** runs **on the device** (see 5.4 for the two options compared in Sprint 13).
- **When the recognizer is unsure,** Bolt asks, "Did you write 7?" with big Yes and Try-again buttons. A misread is never marked wrong.
- **Numeral-formation coaching** (optional, parent setting): if a digit is consistently reversed (common at age 6, e.g., a backward 7), Bolt shows an animated stroke-order demo now and then. It's never a penalty.
- **Works with a finger too,** so it works on any tablet or touchscreen Chromebook. Mouse-only players use the number pad instead.

---

## 4. Rewards and motivation

| Reward | How it works | Why it motivates |
|---|---|---|
| **Gems and coins** | Earned from every solved rock. Rare gems come from rare numbers (e.g., **twin primes** drop as twin gems; **Mersenne primes** like 127 are legendary). | Instant feedback, and the rarest rewards come from the math itself |
| **Gem Museum** | Display cases for collected gems. Each real mineral (quartz, garnet, pyrite…) has a narrated fun fact. | Collecting, plus earth science |
| **Tools and upgrades** | Better pickaxes, a bigger cart and a faster elevator, crafted with math recipes | Visible progress and power |
| **Bolt customization** | Headlamp colors, paint and stickers for the robot | Ownership and identity |
| **Mine-engineering builds** | Machines he builds stay in the mine and keep working, carrying gems up | Matches his love of building |
| **Mathematician badges** | Badges named for Eratosthenes, Euclid, Fermat, Sophie Germain, Gauss, Ramanujan and Emmy Noether, each with a 30-second narrated story | Heroes and history |
| **Lantern streak** | A lantern lights for each day played. Missed days **pause** the streak; it never resets to zero. | Encourages habit without guilt |
| **Weekly "Deep Dig"** | A weekly expedition mixing all his skills, with a special gem at the end | A "boss level" for review |
| **Family reward points** | Parents set real-world rewards in the parent area (e.g., 500 points = a small Lego set) | Connects effort to real life |
| **Fib poems** (Zone 9+) | He unlocks and later writes short poems whose syllable counts follow the Fibonacci sequence (1, 1, 2, 3, 5, 8) | Brings poetry in through the math |

**Guardrails:**

- Rewards come from effort and mastery, not speed or luck.
- There are no random paid loot boxes and no countdown timers for young ages.
- There's no "come back now!" pressure, and there are no notifications unless a parent turns them on.
- Wrong answers never cost gems.

These guardrails also line up with Google Play's expectations for children's apps.

---

## 5. Tools and technology

### 5.1 Recommendation

**Build the game in the Godot Engine (4.7.x) using GDScript, and export it as an Android app.**

- Chromebooks run Android apps from the Google Play Store, so **one Android build covers Charlie's 2-in-1 Chromebook, his tablet, and other families' devices.**
- **Android Studio and Kotlin** are still part of the toolkit, in a supporting role. Android Studio supplies the Android SDK, emulators and profiler. Kotlin is used for one small **Godot Android plugin** that connects handwriting recognition (see 5.5).
- **An AI coding assistant** (for example, Claude Code) speeds up the move from general software engineering to game development. Spiro stays the reviewer of every change.

### 5.2 Why Godot instead of Kotlin and Android Studio (and the other options)

**Kotlin with Jetpack Compose in Android Studio** is the modern standard for regular Android *apps*. For *games*, the standard is a **game engine**, which comes with what games need: animation, particles, sound mixing, scenes, physics, and screen scaling across different devices. Building those yourself in Kotlin would cost months.

| Option | Language | Strengths | Weaknesses for this project | Verdict |
|---|---|---|---|---|
| **Godot 4.7** | GDScript (Python-like) | Free and open source (MIT license, no fees ever). Excellent for 2D. Small app size. Android **and** web export from one project. Quick to learn for an experienced developer. | Smaller plugin ecosystem than Unity | **Recommended** |
| Unity 6 | C# | Industry standard, huge asset store | Heavier engine and larger downloads; steeper editor learning curve; licensing terms have changed before | Strong alternative, but more than this 2D game needs |
| Kotlin + Jetpack Compose (Android Studio) | Kotlin | Google's official app toolkit; native performance | Not a game engine, so you'd hand-build animation, game loop, particles and audio | Used only for the handwriting plugin |
| Flutter + Flame | Dart | Great for UI-heavy apps | Flame is a lighter game engine with a smaller ecosystem | Reasonable, but no advantage here |
| Web app (Phaser + TypeScript) | TypeScript | Runs in any Chrome browser, even locked-down school Chromebooks | Weaker offline audio and storage on tablets; packaging for Play takes extra steps | Not needed: Godot's web export covers this later (Sprint 50) |

### 5.3 Full toolchain

| Purpose | Tool | Notes |
|---|---|---|
| Game engine and editor | **Godot Engine 4.7.x** (standard build) | Free. Pin one exact version and upgrade on purpose, not mid-sprint. Runs on your Windows PC. |
| Programming language | **GDScript** | Python-like. Using it (not C#) keeps the web-export option open. |
| AI coding assistant | **Claude Code** (or your preferred assistant) | Keep a `CLAUDE.md` file in the repository with conventions, architecture notes and testing rules. Have it write tests first for generators and the engine. |
| Android SDK, emulator, debugging | **Android Studio** (latest stable) | Android SDK, emulators (tablet and resizable/desktop profiles), Logcat logs and performance profiler |
| Android plugin (handwriting) | **Kotlin** in Android Studio, using Godot's Android plugin system | A small library that Godot calls for recognition (see 5.5) |
| Java toolchain | **JDK 17** (Eclipse Temurin) | Use the exact JDK version the Godot docs specify for the pinned engine version. |
| Android build | Godot **Gradle build template**, producing **.aab** for Google Play and **.apk** for direct testing | **Target API 36** (Android 16), required by Google Play for new apps and updates from Aug 31, 2026. Keep Godot's default minimum API level so older devices in other families can install it. |
| CPU architectures | **arm64-v8a** (Charlie's 2-in-1 and tablet) **and x86_64** | x86_64 serves other families' Intel/AMD Chromebooks and makes the Android emulator fast on your Windows PC. |
| Offline tools | **Python 3** scripts in the same repository | Voice-generation pipeline, BKT parameter fitting from exported logs, independent math cross-checker, handwriting-model training |
| Voice narration (Phase 3) | **Licensed AI text-to-speech**, generated ahead of time | See 5.6. Not part of the MVP. |
| Audio processing | **ffmpeg** (loudness normalization, OGG encoding) and **Audacity** for spot fixes | Run automatically by the voice pipeline |
| Fonts | **Andika** (SIL, free, Open Font License) | Designed specifically for beginning readers. Especially important because the MVP is text-based. |
| Art | **Kenney.nl** free (CC0) packs for MVP placeholders; **Krita** / **Inkscape**; a **commissioned human artist** for Bolt and key art (Phase 2) | Clear ownership of the main character matters for a published game. Copyright for AI-generated character art is still unsettled. |
| Music and sound effects | Licensed royalty-free packs (check the license allows app use) | |
| Automated tests | **GdUnit4** (Godot), **pytest** (Python tools) | |
| Source control and CI | **Git + private GitHub repository**; **GitHub Actions** running Godot headless | Every merge builds and tests; Friday builds upload to the internal testing track. |
| Task tracking | **GitHub Projects** board | One card per backlog item |
| Distribution | **Google Play Console** | See 5.7 |

### 5.4 Devices and input

**Charlie's 2-in-1 Chromebook (ARM chip, touchscreen, stylus):**

- **Three postures:**
  - **Laptop:** trackpad and keyboard.
  - **Tent:** touch.
  - **Tablet:** touch and stylus, with the keyboard folded away.
- The game must handle switching between them mid-session without losing state.
- **Touch first:** all core interactions are taps and drags with **large targets (at least 64 dp)** for a 6-year-old. There are no multi-finger gestures.
- **Stylus:** used for the chalk slate (handwriting). **Palm rejection:** while a pen stroke is active, ignore other touch points.
- **No system keyboard:** in tablet mode a text field would pop up the on-screen keyboard and cover the play area, so the game uses its own number pad.
- **Orientation:** landscape only. In tablet posture the device may be held in portrait, so Sprint 3 tests how ChromeOS handles a landscape-locked app there.
- **Sprint 1 test:** confirm how the stylus reports in Godot on ChromeOS (pen vs. touch events, pressure), plus trackpad, window and fullscreen behavior.

**Charlie's new Android tablet (buying soon). Suggested minimums:**

- 10–11 inch screen.
- Android 15 or newer.
- 6 GB of RAM or more.
- A long security-update promise from the manufacturer.
- **Stylus support is a nice extra** but not required, since handwriting also works with a finger.

**Other families' devices (needed for the public release):**

- Intel/AMD Chromebooks (x86_64 build).
- **Mouse-only Chromebooks** with no touchscreen: every interaction must also work with click and drag, using the number pad instead of handwriting.
- Smaller and older tablets.
- **Phones are excluded** using screen-size settings in the app manifest and Google Play's device catalog.

**All devices:**

- Fully **offline** with no internet permission. If the ML Kit option in 5.5 is chosen, it needs one exception for its one-time model download.
- Autosave after every rock.
- Under 150 MB download.
- Steady 60 frames per second on mid-range hardware.

### 5.5 Handwriting recognition: two options, decided in Sprint 13

| | **Option A: Google ML Kit Digital Ink Recognition** | **Option B: Your own small digit model (recommended)** |
|---|---|---|
| How it works | Google's handwriting recognizer, called from the Kotlin plugin. Runs on the device after a **one-time ~20 MB language-model download**. Requires Android API 23 or newer. | A small neural network trained on public handwritten-digit datasets (MNIST/EMNIST), with augmentation for children's writing (wobbly strokes, reversed digits, size variation). Exported to **LiteRT** (formerly TensorFlow Lite) and run in the Kotlin plugin, or run directly in GDScript if it's small enough. |
| Pros | Fast to integrate; robust across writing styles | Fully offline and bundled (under 1 MB); tuned for kids; **no third-party data flow**, which simplifies the Families Policy review; you control the accuracy |
| Cons | Needs internet once for the model download; trained mostly on adult writing; another SDK to disclose and review for children's-app compliance | About one sprint of Spiro's time |
| Role | Benchmark in the spike | Production choice, unless its accuracy falls short |

**One-digit-per-box design** turns recognition into a simple 10-class problem, which is why Option B is realistic.

**Success target:** at least 97% top-1 accuracy on a test set that includes about 200 of Charlie's own digits, with a confirmation prompt when confidence is low. Those samples stay on your computer and are used only to evaluate the model.

### 5.6 AI voice pipeline (Phase 3, Sprint 22, after the MVP)

1. **Script source:** all narration lines live in one spreadsheet or CSV in the repository. Each line has an ID, the text, and the context it plays in.
2. **Generate:** a Python script sends new or changed lines to the chosen TTS service, using a **pinned voice ID and model version** so Bolt always sounds the same.
3. **Process:** ffmpeg normalizes loudness and encodes OGG files, which the game imports automatically.
4. **Dynamic numbers:** every number 0–1,000 and common phrase fragments ("plus," "equals," "is worth") are pre-generated and spliced together at runtime.
5. **Provider choice (Sprint 22):** shortlist 2–3 providers, such as ElevenLabs, OpenAI TTS, Google Cloud Text-to-Speech or Microsoft Azure AI Speech. **Let Charlie pick Bolt's voice from 3 samples.** Before committing, confirm the plan's license allows **commercial use in a distributed app.** For example, ElevenLabs paid plans include a commercial license, rights to audio made during a paid period continue after canceling, and ElevenLabs may use generated content to improve its models. Never clone a real person's voice without their consent.
6. **Cost control:** generate in batches per zone, so a paid plan is only needed during generation months.

### 5.7 Distribution and publishing

**Developer account (decide in Sprint 1):**

| | **Personal account** | **Organization account** |
|---|---|---|
| Setup | $25 and identity verification, done in days | $25 plus a legal entity (e.g., an LLC), a **D-U-N-S number** (free, up to ~30 days) and Google's business verification. Typically **4–8 weeks** in total. |
| Before public release | Must run a **closed test with at least 12 opted-in testers for 14 consecutive days** (personal accounts created after Nov 2023) | **Exempt** from the closed-test rule |
| Public listing shows | Your name as the developer | The organization's name |
| Fits if | The game stays mostly a family project | You're serious about publishing (and maybe more titles later) |

**Recommendation:** since you plan to build it ready to publish, **start an organization account in Sprint 1.** The paperwork runs in the background while you build the MVP. Use a personal account only if you'd rather not form an entity. In that case, recruit 12+ tester families by Sprint 24.

**Charlie's devices:** the **internal testing track** (up to 100 testers, builds arrive within minutes). Add Charlie's Family Link account and yours.

**Public release requirements for a children's app** (Phase 3):

- **Target audience and content:** declare the target age groups (likely 6–8 and 9–12). This brings in **Google Play's Families Policy**.
- **Privacy policy** (required), hosted for free (e.g., GitHub Pages).
- **Data safety form:** with no data collected or shared, this is simple, and every SDK must be accounted for.
- **No ads.** Every third-party SDK reviewed for how it handles data.
- **Content rating questionnaire.**
- Google reviews the declared audience, which can take **up to 7 days or longer.**
- The app may be considered for Google's **Teacher Approved** program.
- **Pricing** is still to be decided (see section 12). Free, or a one-time purchase, both fit the no-ads, no-loot-box design.
- **Optional, good practice:** say in the store listing that narration uses a licensed AI voice.

**Every August:** Google raises the required target API level. A yearly update sprint (Sprint 38 in 2027) handles it.

**Future-proofing:** Google is merging ChromeOS and Android into **Aluminium OS**, with limited testing reported for late 2026 and a broad release later (possibly around 2028). A modern ARM 2-in-1 with 8 GB of RAM is the kind of device reported as likely to be upgradable. An Android app is the safest format for both today's Chromebooks and future Android laptops.

---

## 6. Technical architecture

### 6.1 Main modules

| Module | Responsibility |
|---|---|
| **Game shell** | Scene switching, pause menu, settings, landscape and fullscreen handling, posture changes on the 2-in-1, input mapping (touch, pen, mouse, keyboard → the same actions) |
| **Mine** | Rock wall generation, digging animations, cart, gem drops, Bolt's reactions |
| **Answer input** | Tap and drag targets, in-game number pad, **chalk slate** (stroke capture, palm rejection, per-digit boxes), keyboard entry |
| **Handwriting bridge** | GDScript wrapper around the Kotlin plugin (or the GDScript model), returning digit and confidence; falls back to the number pad if unavailable |
| **Workshop and world** | Surface hub, crafting, museum, zone map, mine-engineering build screens |
| **Curriculum data** | The skill graph, stored as human-readable data files (JSON or Godot resources) that the math reviewer can check without reading code |
| **Problem generators** | One generator per skill family. Each one creates a problem, its correct answer, distractors and a narration script. |
| **Adaptive engine** | BKT mastery estimates, skill selection, spaced review, hint ladder, placement quest |
| **Text and narration** | MVP: a single text table with stable line IDs and number placeholders, displayed as kid-friendly text. Phase 3: plays pre-generated clips, splices number clips, highlights words in sync, has a replay button. |
| **Rewards and economy** | Coins, gems, crafting recipes, badges, streak, family reward points |
| **Profiles** (Phase 3) | Up to 4 child profiles per device, each with its own skill states and rewards |
| **Save system** | Local save files in the app's private storage, written after every rock, with a backup copy and versioning so updates never break old saves |
| **Parent area** | Behind a **parental gate** (an adult-level question). Progress dashboard; settings for time limit, rewards, interface mode, handwriting coaching and starting grade; progress export and import. |

### 6.2 Data and privacy (designed for the Families Policy from day one)

- **Stored on the device:** child's first name or nickname, skill states, attempt history (skill, correct or not, time, hints, answer mode), inventory and settings.
- **Never collected:** location, contacts, camera, microphone, advertising IDs, third-party analytics, accounts or sign-in, and handwriting images (strokes are discarded after recognition).
- **Leaves the device only when a parent chooses to.** The parent-gated export creates a file the parent can save or share, for example to move progress between devices or to share with Spiro/Claude to tune the engine.

---

## 7. Team, roles and weekly rhythm

| Role | Who | Time |
|---|---|---|
| **Product owner, developer, producer** | Spiro | ~40 hrs/week |
| **AI coding assistant** | Claude Code (or similar) | Throughout. Spiro reviews and approves all changes. |
| **2D artist** | Contract | Bolt and key art after the go decision (Sprints 15–20); zone art batches after that |
| **Math/curriculum reviewer** | A teacher or math tutor, contract | About 2–4 hrs per zone |
| **Playtester** | Charlie | One observed 15–20 min session per weekend, plus free play |
| **Second observer** | Another adult (e.g., Charlie's other parent or a grandparent) | Watches some playtests, since the developer-parent is the least neutral observer |
| **Tester families** | 12+ families (personal account) or 3–5 families (organization account) | Phase 3 closed test (Sprints 25–26) |

**Ramp-up from software engineer to game developer (Sprint 1):** about 12 hours of Godot learning:

- Godot's official "Your first 2D game" tutorial.
- The GDScript reference.
- The Android export guide.

Plus about 3 hours studying the game feel of well-regarded learning games (e.g., DragonBox Numbers, Khan Academy Kids): how they give feedback, celebrate, and keep text minimal.

**Working with the AI assistant:**

- Generators and the engine are written **test-first**.
- Every math generator is checked by an **independent** Python cross-checker, so a generator and its test can't share the same mistake.
- Keep architecture decisions in `CLAUDE.md` and a `docs/decisions.md` log.
- AI is used **at build time** only (code, scripts, narration audio). The shipped game contains no live AI calls.

**Weekly rhythm:**

- **Monday (30 min):** write the sprint goal and pull backlog items into the sprint.
- **Daily:** small commits; continuous integration builds and tests every merge.
- **Friday:** release build to the internal testing track and install it on both of Charlie's devices. A 15-minute self-demo, plus a short changelog and next-week notes.
- **Weekend:** a Charlie playtest. Watch quietly, don't help unless he's stuck for more than a minute, and log what confused or bored him. Feedback goes into Monday's backlog.
- **Short weeks:** holiday weeks are 3–4-day sprints with reduced scope. A **2-week break** (Dec 21 – Jan 1) protects against burnout.

**Definition of done (applies to every backlog item):**

1. Works on the 2-in-1 in laptop and tablet postures, and on the tablet.
2. Works with touch and stylus, plus mouse/keyboard where relevant.
3. All child-facing text comes from the text table and reads at the right level for Charlie. From Phase 3, every line also has narration.
4. Problem generators pass automated and independent correctness tests.
5. Saves survive closing the app.
6. Merged with a passing build.

---

## 8. Sprint plan (51 one-week sprints)

### 8.1 Phase overview

| Phase | Sprints | Dates | Outcome | Status |
|---|---|---|---|---|
| **1. Ramp-up to MVP** | 1–11 | Nov 2, 2026 – Jan 29, 2027 | **MVP:** Zones 1–3 (text-based), BKT engine, rewards, parent dashboard, on the 2-in-1 and tablet | **Committed** |
| **2. Version 1.0** | 12–21 | Feb 1 – Apr 9, 2027 | Handwriting, Zones 4–5, crafting and engineering, cross-device progress, badges, art, polish | Provisional (decision gate Feb 19) |
| **3. Public release readiness** | 22–28 | Apr 12 – May 28, 2027 | **AI-voice narration**, profiles, Families Policy compliance, broad device support, store listing, closed test, **public launch** | Provisional |
| **4. Middle mountain** | 29–40 | May 31 – Aug 20, 2027 | Zones 6–9, Scholar mode begins, yearly Android update. Each zone ships as a free content update. | Provisional |
| **5. Deep mountain** | 41–52 | Aug 23 – Nov 12, 2027 | Zones 10–12 (modular arithmetic and groups, ciphers, proof), Scholar mode complete, web version | Provisional |

### 8.2 Phase 1: Ramp-up to MVP (Sprints 1–11) — committed

**Sprint 1 (Nov 2–6): Setup, Godot ramp-up, device test**
- **Accounts:** decide personal vs. organization developer account. If organization, start the LLC and **D-U-N-S** request now. Create the GitHub repository and `CLAUDE.md`.
- **Install:** Godot 4.7.x, Android Studio, SDK for API 36, JDK 17.
- **Learn:** Godot ramp-up (about 12 hours, see section 7) and the game-feel study (about 3 hours).
- **Build a "hello rock" app** (one tappable rock with a sound) and run it on the **2-in-1 in all three postures** and the tablet. Use the emulator if a device hasn't arrived yet; both devices are needed by Sprint 3. Confirm touch, **stylus events**, trackpad, fullscreen and landscape lock.
- **Done when:** the test app installs from the internal testing track on both devices.

**Sprint 2 (Nov 9–13): Game design and curriculum**
- Write a short game design document (core loop, screens, rewards, tone).
- Build **skill map v1**: Zones 1–3 in full detail (about 45 skills), Zones 4–12 outlined. The math reviewer checks Zones 1–3.
- Choose the placeholder art direction from CC0 packs.
- **Charlie playtest:** a paper prototype. Use paper "rocks" and real Lego bricks as ten-bars and one-gems, to test whether "trading ten" makes sense to him.

**Sprint 3 (Nov 16–20): Architecture**
- Game shell: title, hub, mine scene flow, pause menu, settings.
- Unified input mapping (touch, pen, mouse, keyboard). Posture changes. Landscape behavior in tablet posture.
- In-game number pad.
- **Text system:** all child-facing text in one table with stable line IDs and number placeholders, so narration can be added in Phase 3 without reworking screens.
- Save system v1 (autosave, backup copy, version number).
- GdUnit4 and pytest running in continuous integration.

**Sprint 4 (Nov 23–25, 3 days because of Thanksgiving): Core dig loop (gray-box)**
- Rock wall, tap or drag to answer, crack animation, gem drop and mine cart, using placeholder shapes and one hard-coded problem type.
- **Charlie playtest over Thanksgiving weekend: the "is digging fun?" test.** If the loop isn't fun with plain shapes, fix the loop before adding content.

**Sprint 5 (Nov 30–Dec 4): Problem generators and Zone 1 content**
- Generator framework (problem, answer, distractors, narration script).
- Zone 1 generators: counting to 120, comparing, building and reading tens and ones, regrouping.
- Python cross-checker plus 10,000-problem automated tests per generator.

**Sprint 6 (Dec 7–11): Adaptive engine v1 (BKT)**
- Per-skill BKT, mastery rule, frontier selection, spaced-review queue, attempt logging.
- Hint ladder steps 1–2. Placement quest (seeded from the Star results).
- Simulated-learner test suite.

**Sprint 7 (Dec 14–18): Zone 2 content and kid-friendly text**
- Zone 2 generators: addition and subtraction within 20 and within 100 with regrouping, fact families, missing addends.
- **Readable on-screen text:** Andika font at large sizes, short sentences, Bolt's speech bubbles. Key math terms can be tapped to show a picture and a kid-sized definition (Word Gems).
- Write every MVP line in the text table (about 300 lines) and check the reading level with Charlie.
- Time freed by moving narration out of the MVP becomes **buffer** for game-feel polish on the dig loop.

> **Holiday break: December 21, 2026 – January 1, 2027.** Charlie can play the Zone 1–2 build informally over the break. The play logs give the first real data for tuning.

**Sprint 8 (Jan 4–8): Rewards v1**
- Coins and gem types. Gem Museum with 10 real minerals and narrated facts.
- Two tool tiers and three Bolt customization items.
- Lantern streak. Session timer with Bolt's wind-down. Celebration effects.
- Hint ladder steps 3–4.

**Sprint 9 (Jan 11–15): Zone 3 content and parent area**
- Zone 3 generators: skip counting, even/odd, arrays, multiplication as equal groups.
- Parental gate plus **parent dashboard v1**: time played, skills mastered, struggling skills, session-length setting, progress export.

**Sprint 10 (Jan 18–22, 4 days because of MLK Day): Look, sound and first-run**
- Placeholder-art pass so Zones 1–3, the hub and Bolt look coherent.
- Sound effects. First-run onboarding.
- Target-size and readability check (every screen understandable from its text and pictures).

**Sprint 11 (Jan 25–29): MVP hardening and release**
- Bug bash. Performance check on both devices.
- Tests for posture changes, save and resume, updating over an old version, and offline play.
- Release-signed build to internal testing, installed on both devices.
- Charlie plays a full session on his own.

> ## MVP MILESTONE: end of Sprint 11 (Friday, January 29, 2027)
>
> **What the MVP includes:**
> - Zones 1–3 (about 45 skills): counting, place value, regrouping, addition and subtraction within 100, fact families, skip counting, even/odd, arrays and early multiplication. This covers exactly his weakest Star areas, plus a first step beyond grade level.
> - The full dig, collect and surface loop; workshop hub; Gem Museum; tools; Bolt customization; lantern streak.
> - BKT adaptive engine with placement, mastery, spaced review and the hint ladder.
> - Kid-friendly on-screen text (large Andika font, short sentences, speech bubbles), all from one text table so narration can be added later.
> - Tap, drag and number-pad answers.
> - Parent dashboard v1 with time limit and progress export.
> - Runs offline on the **2-in-1 Chromebook (all postures) and the Android tablet**, installed from Google Play internal testing.
>
> **Not in the MVP:** AI-voice narration (Phase 3), handwriting answers, crafting, engineering projects, Zones 4–12, cross-device progress (each device keeps its own progress; manual export and import only), badges, Deep Dig, family reward points, Scholar mode, commissioned art, public release.
>
> **Acceptance criteria:**
> 1. Charlie can start and finish a 20-minute session on either device with no adult help after his first session.
> 2. Zero crashes across 5 consecutive playtest sessions.
> 3. Every generator passes its automated and independent correctness checks.
> 4. Progress survives closing the app, switching posture, restarting the device and installing an update.
> 5. The dashboard's list of mastered skills matches what an adult observer would judge.
>
> **Decision gate: end of Sprint 14 (Friday, February 19, 2027).** Development continues meanwhile. After 3 weeks of real play, look at:
> - Does Charlie **ask** to play?
> - Does he play on at least 3 days a week without being pushed?
> - Is his mastered-skill count rising?
> - Is the MVP pace fast enough for you, with Sprints 12–52 at the same speed?
>
> Then choose to **continue as planned**, **adjust** (for example, more building and less digging), **pause** (keep the MVP as a family game), or **stop**.

### 8.3 Phase 2: Version 1.0 (Sprints 12–21) — provisional

| Sprint | Dates | Goal and main deliverables |
|---|---|---|
| **12** | Feb 1–5 | **MVP feedback and tuning.** Fix playtest issues; first BKT parameter fit from exported logs; difficulty tuning. |
| **13** | Feb 8–12 | **Handwriting spike.** Kotlin plugin skeleton. Train a small digit model (Option B), benchmark it against ML Kit (Option A) on a test set including about 200 of Charlie's digits, and choose. |
| **14** | Feb 15–19 (4 days, Presidents' Day) | **Handwriting feature.** Chalk slate with per-digit boxes, finger and stylus, palm rejection, "Did you write 7?" confirmation, optional numeral-formation coaching. *MVP decision gate.* |
| **15** | Feb 22–26 | **Zone 4: Factor Workshop.** Multiplication and division facts, factors, multiples, factor pairs as rectangles, prime vs. composite. "Split the boulder" mechanic. Brief the artist on Bolt and key art. |
| **16** | Mar 1–5 | **Crafting and engineering projects.** Build-screen framework, crafting recipes, first projects (cart track, balance-scale elevator). |
| **17** | Mar 8–12 | **Cross-device progress** (Charlie uses two devices). Choose an approach that fits the Families Policy: parent-managed export/import (file or Google Drive) vs. Google Play Games cloud saves (check its use in children's apps). Build it with "newest wins plus backup." |
| **18** | Mar 15–19 | **Zone 5: Prime Caverns.** Interactive Sieve of Eratosthenes, factor trees, prime factorization, divisibility rules, rare twin-prime and Mersenne-prime gems. |
| **19** | Mar 22–26 | **Long-term motivation.** First 4 mathematician badges, Word Gems glossary, weekly Deep Dig, Challenge Door, family reward points. |
| **20** | Mar 29–Apr 2 | **Art and polish.** Commissioned Bolt and key art integrated; Zones 1–5 art pass; music; animation and particle polish; accessibility pass. |
| **21** | Apr 5–9 | **Version 1.0 hardening.** Parent dashboard v2 (visual skill map, weekly summary). Math reviewer checks Zones 1–5. Performance and save-migration tests. Release to internal testing. |

**Milestone: Version 1.0 (private) at the end of Sprint 21 (April 9, 2027)**

### 8.4 Phase 3: Public release readiness (Sprints 22–28) — provisional

| Sprint | Dates | Goal and main deliverables |
|---|---|---|
| **22** | Apr 12–16 | **AI-voice narration** (moved here from the MVP). Shortlist providers and check commercial licenses; **Charlie picks Bolt's voice** from 3 samples. Build the generation pipeline (see 5.6). Narration manager: number-clip splicing, word highlighting, replay button. Generate every line for Zones 1–5 plus numbers 0–1,000. |
| **23** | Apr 19–23 | **Families who aren't us.** Up to 4 child profiles per device. **Read-aloud setting per profile** (on by default for younger or non-reading players, optional for Charlie). Generic placement (parent picks a starting grade). Parent onboarding. A parent-facing "how this game teaches" page. |
| **24** | Apr 26–30 | **Compliance.** Privacy policy (hosted on GitHub Pages); data safety form; target audience (ages 6–8 and 9–12); content rating questionnaire; SDK audit; parental-gate review; Families Policy self-check. |
| **25** | May 3–7 | **Broad device support.** x86_64 build. **Mouse-only Chromebook path** (no touch, no pen). Small and older tablets. Low-end performance. Phone exclusion. Emulator test matrix. Recruit tester families (12+ if personal account). |
| **26** | May 10–14 | **Store listing and closed test.** Icon, screenshots, feature graphic, short trailer, description (with an optional AI-voice note). **Closed test starts** and must run 14 consecutive days if on a personal account. |
| **27** | May 17–21 | **Closed-test fixes.** Bugs and feedback from other families (especially first-time onboarding and read-aloud with non-readers); a mid-test build. |
| **28** | May 24–28 | **Launch.** Final build. Request production access (personal account) or submit directly (organization account). Allow up to about 7 days for Google's review of a children's app. |

**Milestone: public Version 1.0 on Google Play around early June 2027** (after Google's review)

### 8.5 Phase 4: Middle mountain (Sprints 29–40) — provisional

Each new zone follows a three-sprint pattern, then ships to the public as a free content update:

1. **Curriculum and generators,** with independent checks and math-reviewer sign-off.
2. **New mechanic and engineering project.**
3. **Art, voice batch, integration, polish and release.**

| Sprint | Dates | Goal and main deliverables |
|---|---|---|
| **29** | Jun 1–4 (4 days, Memorial Day) | **Zone 6 Gear Works:** GCF, LCM, simplest form; generators and checks. |
| **30** | Jun 7–11 | Zone 6: **gear-train machine builder.** Charlie designs gear trains so machines sync up, using LCM in practice. |
| **31** | Jun 14–17 (4 days, Juneteenth) | Zone 6: art, voice, polish, **release.** |
| **32** | Jun 21–25 | **Zone 7 Crystal Shards:** fractions, equivalent fractions, comparing and adding; generators and checks. Handwriting extended to fractions (numerator and denominator boxes). |
| **33** | Jun 28–Jul 2 | Zone 7: crystal-splitting mechanic, decimals, percents, alloy-mixing ratio project, negative numbers on a depth gauge. |
| **34** | Jul 6–9 (4 days, July 4 observed) | Zone 7: art, voice, polish, **release.** |
| **35** | Jul 12–16 | **Zone 8 Power Tower:** exponents, square and cube numbers, square roots, powers of 2 and 10; generators and checks. |
| **36** | Jul 19–23 | Zone 8: binary vault-lock puzzles, other bases, scientific notation, elevator-counterweight project. |
| **37** | Jul 26–30 | Zone 8: art, voice, polish, **release.** **Scholar mode, part 1:** keyboard entry and on-screen math notation. |
| **38** | Aug 2–6 | **Yearly platform update:** move to the new target API level ahead of Google Play's annual August 31 deadline; Godot upgrade check; full regression testing; release. |
| **39** | Aug 9–13 | **Zone 9 Pattern Grotto:** sequences, triangular and square numbers, Fibonacci, golden ratio, Gauss's sum; generators and checks. |
| **40** | Aug 16–20 | Zone 9: proof-without-words puzzles, **Fib poem maker**, art, voice, polish, **release (Version 1.5).** |

### 8.6 Phase 5: Deep mountain (Sprints 41–52) — provisional

| Sprint | Dates | Goal and main deliverables |
|---|---|---|
| **41** | Aug 23–27 | **Zone 10 Clockwork Depths:** modular arithmetic on circular tracks and clock locks, remainders, congruence notation (a ≡ b mod n); generators and checks. |
| **42** | Aug 30–Sep 3 | Zone 10: **cyclic group ℤₙ.** Identity, inverse and closure, explored with a "mixing table" (a Cayley table) and vault locks. Why divisibility rules work. |
| **43** | Sep 7–10 (4 days, Labor Day) | Zone 10: art, voice, polish, **release.** |
| **44** | Sep 13–17 | **Zone 11 Cipher Vault:** Caesar and affine ciphers, modular inverses; generators and checks. |
| **45** | Sep 20–24 | Zone 11: animated Euclidean algorithm (basic and extended), coin-puzzle Diophantine equations, toy RSA with small primes. A **"secret message" feature** lets Charlie encode a note for you to decode on paper. |
| **46** | Sep 27–Oct 1 | Zone 11: art, voice, polish, **release.** |
| **47** | Oct 4–8 | **Zone 12 Infinite Core:** Mathematician's Journal, a drag-tile proof builder. |
| **48** | Oct 11–15 | Zone 12: guided proofs (infinitely many primes, √2 is irrational), integers, rationals and reals. |
| **49** | Oct 18–22 | Zone 12: "Unsolved Mysteries" room (Goldbach conjecture, twin primes), art, voice, polish, **release.** |
| **50** | Oct 25–29 | **Scholar mode complete.** Remaining mathematician badges (Noether, Ramanujan, Germain…). "Master Miner" ranks. |
| **51** | Nov 1–5 | **Web version** (for families with locked-down school Chromebooks), full regression testing, math reviewer final check of Zones 10–12. |
| **52** | Nov 8–12 | **Version 2.0 release.** Final hardening. Documentation: build and release guide, "how to add a zone" guide, curriculum data guide. |

**Milestone: Version 2.0, the full game, at the end of Sprint 52 (November 12, 2027)**

### 8.7 After Sprint 52: maintenance mode

About **2–4 days per month** covers:

- The **yearly target-API update** each August.
- Godot upgrades and bug fixes.
- BKT re-tuning as Charlie plays.
- Responding to public reviews.
- Optional new gems, challenges and deeper problems.

Charlie will be about 7 at this point. The game already holds content through about age 12, and he grows into it at his own pace.

---

## 9. Testing and quality

| Area | How it's tested |
|---|---|
| **Math correctness** | Each generator produces 10,000 problems in automated tests. An **independent Python checker** (written separately from the generator) verifies every answer, and distractors must never equal the right answer. The math reviewer checks wording and samples per zone. |
| **Adaptive engine** | Simulated learners (fast, average, slow, random guesser, a "forgetter"). BKT fits checked against held-out play logs. |
| **Handwriting** | Accuracy of at least 97% on a test set including Charlie's digits. Low-confidence answers always trigger confirmation. Measured false-wrong rate. |
| **Devices** | Every Friday: the **2-in-1 in laptop, tent and tablet postures**, and the tablet. Plus emulators: tablet, resizable/desktop and x86_64 Chromebook profiles. From Phase 3, a **mouse-only** run of every screen. |
| **Input** | Every screen completed with touch only, stylus only, and (from Phase 3) mouse only and keyboard only. |
| **Saves** | Close the app mid-dig, switch posture, restart the device, install an update over an old save, sync conflicts (from Sprint 17), multiple profiles (from Sprint 22). |
| **Offline** | Airplane mode for a full session. |
| **Child accessibility** | MVP: reading-level check of every line, touch targets at least 64 dp, color never the only clue (gems also differ by shape). From Phase 3: 100% narration coverage, and no reading needed with read-aloud on. |
| **Compliance** (Phase 3) | Families Policy self-check, SDK and permission audit, privacy policy matches actual behavior. |
| **Fun and learning** | Weekly playtests with Charlie (some observed by a second adult). Monthly comparison with your home-plan checkpoints; his winter and spring Star tests. Phase 3: feedback from tester families. |

---

## 10. Risks and how to manage them

| Risk | Likelihood | Mitigation |
|---|---|---|
| **New to game development:** the game works but doesn't *feel* fun | Medium | Game-feel study in Sprint 1; "is digging fun?" test in Sprint 4 with gray boxes; polish time in every zone's third sprint; borrow proven feedback patterns (squash and stretch, particles, sound on every action). |
| **Solo developer:** one person is the only builder, and burnout is possible | Medium | Holiday break and short weeks; the MVP decision gate; Sprints 12–51 provisional; all code tested and documented as you go, so it can pause and restart cleanly. |
| **Parent-developer bias** in playtests | Medium | A second adult observer for some sessions; rely on play logs; tester families in Phase 3. |
| The game isn't fun for Charlie | Medium | Sprint 4 test; weekly playtests; decision gate. |
| It feels like drill, not play | Medium | Mix of new skills and review; builds, crafting and the museum break up digging; no timers for young ages. |
| Handwriting misreads frustrate him | Medium | Per-digit boxes; confirmation prompt; never marked wrong on low confidence; the number pad is always available. |
| Some text is too hard for Charlie (math terms, longer instructions) | Low–Medium | Short sentences; tappable Word Gems with pictures; weekly playtests; a parent can read along; narration arrives in Phase 3. |
| 2-in-1 quirks (posture switching, portrait in tablet mode, stylus events) | Low–Medium | Device test in Sprint 1; posture tests in every Definition of done. |
| **Google Play rejects or delays the children's app review** | Medium | Compliance designed in from day one (no ads, no data collection); dedicated compliance sprint; allow a week or more for review. |
| Can't find 12 testers for the closed test (personal account) | Medium | Organization account (exempt), or recruit from school and friends early (Sprint 24). |
| AI voice license or provider changes | Low–Medium | Confirm commercial terms before generating; keep all generated audio files in the repository; pinned voice ID; scripts make re-generation with a new provider easy. |
| Charlie moves faster (or slower) than the content | Medium | BKT engine and Challenge Door; content built ahead of where he is. |
| Too much screen time | Medium | Parent-set limit; wind-down; streaks that never punish; real-world reward tie-ins. |
| Scope creep (especially fun AI ideas) | Medium | New ideas go into the backlog, not the current sprint; no live AI in the shipped game. |

---

## 11. Budget outline

**Your time:**

| Milestone | Approximate hours (40/week, less holidays) |
|---|---|
| MVP (Sprints 1–11) | ~416 hours |
| Version 1.0 private (through Sprint 21) | ~808 hours |
| Public launch (through Sprint 28) | ~1,088 hours |
| Version 1.5 (through Sprint 40) | ~1,544 hours |
| Version 2.0 full game (through Sprint 52) | ~2,016 hours |

**Cash costs (MVP-first):**

| Item | When | Cost |
|---|---|---|
| 2-in-1 Chromebook and Android tablet | Before Sprint 3 | Already planned |
| Google Play developer account | Sprint 1 | $25 one-time |
| LLC and D-U-N-S (organization account only) | Sprint 1 | State LLC filing fees vary; D-U-N-S is free |
| Godot, Android Studio, JDK, Krita, Inkscape, Audacity, ffmpeg, GdUnit4, Andika font, GitHub Pages | Throughout | Free |
| AI coding assistant subscription | Throughout | Monthly subscription |
| AI voice service (paid plan with commercial license) | Phase 3 onward, generation months only | Low monthly fee; check current pricing |
| Math reviewer | ~2–4 hrs per zone | Hourly rate |
| **After the go decision:** commissioned art for Bolt and key art, then zone art batches | Sprints 15–20, then per zone | Get quotes |
| Music and sound-effect packs | Sprint 10 / 20 | Small one-time license fees |
| GitHub private repository and Actions | Throughout | Free tier is likely enough |

**MVP cash spend is minimal:** account fees, a few hours of math review and the AI coding subscription. The AI-voice plan isn't needed until Phase 3. The larger spending (art) only starts if the decision gate says go.

---

## 12. Decisions needed

**Before Sprint 1 (by November 2, 2026):**

1. **Developer account type:** organization (recommended, start the LLC and D-U-N-S now) or personal.
2. **Device timing:** buy the 2-in-1 and the tablet by mid-November (needed by Sprint 3).
3. **Charlie's Google account** (Family Link) to add as an internal tester.
4. **Defaults:** session length (suggested 20 minutes) and what real-world rewards family points can earn.

**During Phase 1:**

5. **Go / adjust / pause / stop** at the decision gate (February 19, 2027).

**Before public launch:**

6. **Bolt's voice:** provider and voice (Sprint 22, with Charlie's vote).
7. **Pricing:** free, paid upfront, or free with a one-time "unlock the deep mountain" purchase. No ads and no loot boxes in any case.
8. **Name and branding:** check the game name is available as a store listing and web domain.
9. **Artist:** commission Bolt and key art (Sprint 15 brief).

---

## Sources

- [Google Play target API level requirements (Android Developers)](https://developer.android.com/google/play/requirements/target-sdk): new apps and updates must target Android 16 (API 36) from Aug 31, 2026.
- [Godot Engine release blog](https://godotengine.org/blog/release): Godot 4.7 (June 2026) and 4.7.2 (Aug 2026) are the current stable releases.
- [Export your game to Android in Godot 4 (Summer Engine, 2026)](https://www.summerengine.com/blog/export-game-android-godot)
- [Godot docs: Text to speech](https://docs.godotengine.org/en/stable/tutorials/audio/text_to_speech.html)
- [ML Kit Digital Ink Recognition on Android (Google)](https://developers.google.com/ml-kit/vision/digital-ink-recognition/android): about 20 MB model per language, downloaded once; minimum API 23.
- [Manage target audience and app content settings (Google Play Console Help)](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en): Families Policy, privacy policy, ads SDK rules, content rating, review times.
- [Personal vs. organization Google Play accounts and the 12-tester rule (OnTest, July 2026)](https://ontest.app/blog/personal-vs-organization-google-play-account-12-testers)
- [Google Play's closed-testing requirement in 2026 (ExtendsClass)](https://extendsclass.com/blog/google-plays-closed-testing-requirement-what-developers-need-to-know-in-2026)
- [Google Play internal vs. closed vs. open testing (Indie Hackers, Sept 2026)](https://www.indiehackers.com/post/google-play-internal-vs-closed-vs-open-testing-guide-ffe63a3057)
- [AI voice acting for games: tools, costs and rules (Cinevva, 2026)](https://app.cinevva.com/guides/ai-voice-acting-games): commercial licensing for ElevenLabs and others.
- [Aluminium OS and which Chromebooks may be left out (tbreak)](https://tbreak.com/aluminium-os-chromebooks-incompatible-uae-2026-5/)
- [Is Google's Aluminium OS releasing this year? (PCWorld, Feb 2026)](https://www.pcworld.com/article/3052222/is-googles-aluminium-os-releasing-this-year-sort-of.html)
- Charlie's September 2026 Star results and home plan (Charlie's Education project notes)
