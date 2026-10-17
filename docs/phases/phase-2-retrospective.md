# Phase 2 retrospective (Sprints 12 to 21)

Written at the end of the Phase 2 code (2026-10-17), ahead of the calendar: the sprints were built in code before their dates, so the parts that need Charlie, the devices or a person are still open. Update the "Still open" list as they close, and add the playtest findings when they exist.

## What shipped in code

- **Answering by hand** (Sprints 13-14): a small digit network run in GDScript, the chalk slate with palm rejection and "Did you write 47?", no plugin and no SDK.
- **Two new zones** (15, 18): Factor Workshop (16 skills) and Prime Caverns (11 skills), every generator with a seeded suite and an independent Python checker; 72 skills in all pass the 10,000-problem cross-check. The boulder, the sieve grid and the factor tree are the new mechanics; rare gems come from rare numbers.
- **Making things** (16): a crafting bench with four recipes and two build projects; the balance elevator opens Zone 4.
- **Two devices** (17): save schema v2, newest-wins import with backups, a checksum and a log; no accounts and no cloud.
- **Reasons to come back** (19): four mathematician badges, the Word Gems glossary, a weekly Deep Dig, the Challenge Door, family reward points, all earned and none random.
- **Look and sound without an artist** (20): Bolt's six poses from CC0 frames and tweens, zone tints and banners, Number Mountain on the hub, per-zone synthesized music with a cross-fade, and screenshots at every supported aspect ratio.
- **For grown-ups** (21): dashboard v2 (skill map, weekly summary with the handwriting confirmation rate), the math review packet, the release checklist.

## What went well

- **Data-driven content held up.** Recipes, builds, badges and skills are JSON with validators and tests, so most Sprint 16-19 work was data plus one small rule class each.
- **Pure rules, thin scenes.** `WorkshopRules`, `SaveMerge`, `MotivationRules` and `ProgressReport.week_summary` are tested without scenes; the scene tests only drive the screens.
- **The simulated learners paid off again:** the Challenge Door's "under 2% for a guesser" check showed that three problems are not enough for a two-way skill, which led to the door asking more problems when they are easy to guess.
- **Screenshots caught a real bug** (the glossary at 4:3) that the touch-target audit could not.

## What to watch

- **Nothing here has met a child yet.** Every playtest question (the elevator, the sieve, the badge story, the decision gate) is still open; tune from logs, not guesses.
- **Device-only unknowns** remain the biggest risk: the stylus on ChromeOS, `is_touchscreen_available()`, the native file picker's paths, frame times on the ARM Chromebook.
- **One flaky test was found and fixed** (a cross-device test depended on the wall clock); keep tests off real time.
- **The human math review** of Zones 1-5 has not happened; the AI pre-review is not a substitute.

## Still open (Spiro, the devices, a reviewer)

See `docs/qa/release-1.0.md` for the steps. In short: Charlie's play logs and the decision gate; his digits against the 97% bar; Zone 4 and Zone 5 prerequisite sign-off; the human math review; the device matrices (save migration, posture and input, cross-device round trip, airplane mode); frame times; the Android version code and name; the release AAB; the `v1.0.0` tag; the MNIST licence question before the public release.

## Hand-off to Phase 3

The phase plan's hand-off list (`docs/phases/phase-2-version-1-0.md`, last section) holds, with two differences: the save is at **version 2**, not 3 (one migration covered every Phase 2 record, Spiro's choice), so the Phase 3 profiles migration is v2 to v3; and there is **no LiteRT entry** in the SDK audit (the network runs in GDScript). Every child-facing line is in `text/lines.csv` with placeholders, ready for the Sprint 22 narration batch.
