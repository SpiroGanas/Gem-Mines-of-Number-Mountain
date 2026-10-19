# Phase 3: Public release readiness

> **Changed 2026-10-19 (Spiro):** no narration and no AI voice. Sprint 22 (voice pipeline, `Narration` autoload), the read-aloud setting, narration coverage and the AI-voice listing note are dropped; the children this game is for read. Phones are supported (no phone exclusion). See `docs/decisions.md`, 2026-10-19.

Detailed implementation plan for Phase 3 of *Gem Mines of Number Mountain*. The master plan is `docs/development-plan.md` (section 8.4 is the source for this phase). The previous phase is `docs/phases/phase-2-version-1-0.md`; the next is `docs/phases/phase-4-middle-mountain.md`. Everything in `CLAUDE.md` applies: the non-negotiable rules, the content rules, the "ask Spiro before" list and the definition of done.

## Overview

| Item | Value |
|---|---|
| Phase | 3 of 5: Public release readiness |
| Sprints | 22–28 (seven one-week sprints) |
| Dates | April 12 – May 28, 2027 |
| Status | Provisional (confirmed at the decision gate of Feb 19, 2027, and again after Version 1.0 ships) |
| Milestone | **Public Version 1.0 on Google Play**, around early June 2027 after Google's children's-app review |
| Entry gate | Version 1.0 (private) released to internal testing at the end of Sprint 21 (April 9, 2027) |
| Owner | Spiro, with an AI coding agent; Charlie picks Bolt's voice; tester families in Sprints 26–27 |

**Outcome.** The private Version 1.0 becomes a game other families can install from Google Play. Bolt speaks every line with a licensed AI voice generated ahead of time, so a child who can't read yet can play with read-aloud on. A device holds up to four child profiles. The app passes Google Play's Families Policy because it never had any network access, ads, accounts or analytics to remove. It runs on Intel/AMD Chromebooks, mouse-only Chromebooks and smaller tablets. A store listing, a privacy policy and a closed test complete the launch.

**Out of scope for Phase 3** (goes to the backlog, not the sprint):

- New zones or new math content (Zones 6–12 are Phases 4–5).
- Scholar mode (starts in Sprint 37).
- Web export (Sprint 51).
- Cloud sync beyond what Sprint 17 shipped (parent-managed export/import stays the only cross-device path unless Sprint 17 chose otherwise).
- Live text-to-speech at runtime. `DisplayServer.tts_*` is not used in the shipped game; narration is pre-generated audio only. (Reason: a consistent, licensed voice, and no dependency on device TTS engines.)
- Pricing experiments, in-app purchases (never) or ads (never).

## Entry criteria

Phase 3 starts only when all of these are true. Check them in Sprint 22's Monday planning and list any gap as a Sprint 22 backlog item.

1. **Version 1.0 private build** is installed on the 2-in-1 (all three postures) and the tablet from the internal testing track, with Zones 1–5, handwriting (`ChalkSlate` with the digit network run in GDScript), crafting and engineering projects, cross-device progress, badges, Bolt's CC0-and-code poses and the Sprint 20 polish pass (no commissioned art: Spiro's decision).
2. **Text table is complete for Zones 1–5.** Every child-facing line in `text/lines.csv` has an ID, text and context, and `tools/ci/lint_content.py` passes (no hard-coded child strings, no `LineEdit` in child scenes, no banned content keywords).
3. **Save schema** is at a known `schema_version` (call it `N`) with migrations and fixtures for every prior version in `tests/save/fixtures/`.
4. **Math reviewer sign-off** on Zones 1–5 is recorded in `docs/decisions.md`.
5. **Developer account** is active (organization or personal; see Decisions). If personal, the 12-tester requirement is already known and recruiting starts in Sprint 25 at the latest.
6. `docs/sdk-audit.md` lists every plugin already in the build: GdUnit4 (editor/test only, not shipped), `digit_ink` (own Kotlin plugin, on-device, no network), plus anything approved in Phase 2.
7. CI is green on `main`: `--import`, GdUnit4 suites, `pytest tools`, `tools/crosscheck/run.py --all`, `lint_content.py`.

## Architecture and design

### 3.1 Text table changes (`text/lines.csv`)

The MVP table has columns `id, text, context, voice_version`. Phase 3 makes `voice_version` live. Add one more column and keep the file sorted by `id` so diffs are readable.

| Column | Type | Meaning |
|---|---|---|
| `id` | string | Stable line ID, `zone.context.purpose`. Never renamed or reused. |
| `text` | string | Display text with placeholders `{n}`, `{a}`, `{b}`, `{term}`. |
| `context` | string | Where it plays (`bolt_bubble`, `prompt`, `hint`, `museum_fact`, `badge_story`, `parent_ui`). Lines with `context` starting with `parent_` are **never narrated** and are not counted in coverage. |
| `voice_version` | int | Bumped by `tools/voice/generate.py` after a successful generation. `0` means never generated. |
| `text_hash` | string | New. SHA-1 of `text` at the time audio was last generated. The pipeline regenerates a line when `sha1(text) != text_hash`. |

Rules the agent must keep:

- Changing a line's text does **not** edit `voice_version` or `text_hash` by hand; the pipeline does that. A line whose hash no longer matches is "stale" and CI fails on stale lines in a release build (see Testing).
- Deprecating a line: add `deprecated_by=<new id>` in `context` (e.g. `prompt;deprecated_by=z1.dig.prompt_build_number_v2`) and leave the audio file in place for one release so old saves referencing it still work. Delete in the following release.
- Numbers are never baked into text. A line such as `"This rock is worth {n}."` is one audio clip for the fixed words and one spliced number clip at runtime.

### 3.2 Voice pipeline (`tools/voice/`)

A Python 3.12 package, run offline on Spiro's Windows PC (Git Bash). It **calls a paid API**; per `CLAUDE.md`, ask Spiro before running anything other than `--dry-run`.

```
tools/voice/
  generate.py          # CLI entry point
  providers/
    base.py            # Provider protocol
    elevenlabs.py      # one adapter per shortlisted provider
    openai_tts.py
    google_tts.py
    azure_speech.py
  segmenter.py         # splits a line into fixed fragments and placeholder slots
  numbers.py           # builds the 0–1000 number list and phrase fragments
  postprocess.py       # ffmpeg: loudness normalize, trim silence, encode OGG
  timing.py            # per-word timestamps for highlighting
  manifest.py          # writes narration/manifest.json
  config.toml          # pinned provider, voice_id, model_id, loudness target
tests/ (pytest, under tools/voice/tests/)
```

**Provider adapter** (one class per provider; the rest of the pipeline never imports a provider SDK directly):

```python
class Provider(Protocol):
    name: str
    def synthesize(self, text: str, voice_id: str, model_id: str) -> SynthResult: ...
    def estimate_cost(self, texts: list[str]) -> float: ...

@dataclass
class SynthResult:
    audio_bytes: bytes          # provider's native format (mp3/wav)
    sample_rate: int
    word_timestamps: list[tuple[str, float, float]] | None  # if the provider returns them
```

Secrets come from environment variables only (`ELEVENLABS_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_APPLICATION_CREDENTIALS`, `AZURE_SPEECH_KEY`). Never read them from a file in the repo and never print them.

**What gets generated:**

| Set | Source | Output path | Count (Zones 1–5) |
|---|---|---|---|
| Line fragments | every narrated row in `text/lines.csv`, split at placeholders | `narration/audio/lines/<id>/<k>.ogg` (`k` = fragment index) | ~600 lines, ~900 fragments |
| Numbers | 0–1000 spoken as cardinals; also "a hundred" variants are **not** generated, the splicer always says "one hundred" for consistency | `narration/audio/numbers/<n>.ogg` | 1,001 |
| Phrase fragments | fixed list in `numbers.py`: `plus`, `minus`, `times`, `equals`, `is worth`, `tens`, `ones`, `hundreds`, `and`, each digit name for Chalk Slate confirmations ("Did you write {d}?"), `yes`, `no` | `narration/audio/phrases/<key>.ogg` | ~40 |
| Terms | every term in `curriculum/vocabulary.json` (the word alone, for Word Gems) | `narration/audio/terms/<term_id>.ogg` | ~60 |

`generate.py` subcommands and flags:

```
python tools/voice/generate.py --dry-run          # lists lines missing/stale audio and the cost estimate; no API calls
python tools/voice/generate.py --changed          # generates only missing or stale items, then bumps voice_version/text_hash
python tools/voice/generate.py --all --zone z1    # regenerate a zone batch (cost control: one zone at a time)
python tools/voice/generate.py --samples          # 3 provider/voice samples of 5 fixed lines for Charlie's vote
python tools/voice/generate.py --verify           # offline: every narrated line has every fragment file; exit 1 otherwise
```

**Post-processing** (`postprocess.py`, runs ffmpeg as a subprocess): two-pass `loudnorm` to −16 LUFS integrated, −1.5 dBTP true peak; trim leading/trailing silence below −50 dB with 40 ms padding; encode OGG Vorbis quality 4, mono, 44.1 kHz. All narration shares one target so spliced numbers don't jump in volume.

**Timing** (`timing.py`): if the provider returns word timestamps, store them. Otherwise estimate from fragment duration divided evenly by word count. Timings are stored in the manifest, never in Godot scene files.

**Manifest** (`narration/manifest.json`, generated, committed):

```json
{
  "voice": {"provider": "elevenlabs", "voice_id": "...", "model_id": "..."},
  "lines": {
    "z1.dig.prompt_build_number": {
      "voice_version": 3,
      "fragments": [
        {"file": "lines/z1.dig.prompt_build_number/0.ogg", "words": [["This", 0.0, 0.21], ["rock", 0.21, 0.48], ["is", 0.48, 0.6], ["worth", 0.6, 0.95]]},
        {"slot": "n"},
        {"file": "lines/z1.dig.prompt_build_number/1.ogg", "words": []}
      ]
    }
  },
  "numbers": {"0": "numbers/0.ogg", "...": "..."},
  "phrases": {"plus": "phrases/plus.ogg"}
}
```

The whole `narration/` tree is generated. `CLAUDE.md`: never hand-edit it. Audio stays in the repository (private repo, OGG, Zones 1–5 estimated 25–40 MB; recheck the 150 MB download budget each zone).

**Cost control:** generate per zone, in generation months only; `--dry-run` prints the estimate and the agent reports it to Spiro before any paid run. Keep the paid plan only while generating.

### 3.3 `Narration` autoload (`autoload/narration.gd`)

New singleton registered in `project.godot` after `Text` and `Profiles` (autoload order matters: `Narration` reads both).

```gdscript
class_name NarrationManager
extends Node

signal line_started(line_id: String)
signal word_spoken(index: int)          # index into the display text's word list
signal line_finished(line_id: String)
signal number_spoken(value: int)        # emitted when a spliced number clip starts

@export var min_gap_between_fragments: float = 0.06

var _manifest: Dictionary = {}
var _player: AudioStreamPlayer
var _queue: Array[Dictionary] = []      # resolved fragments for the current line
var _current_line_id: String = ""
var _enabled: bool = true               # mirrors Profiles.active.read_aloud

func _ready() -> void:
    _load_manifest("res://narration/manifest.json")
    Profiles.active_profile_changed.connect(_on_profile_changed)

func is_enabled() -> bool: return _enabled
func speak(line_id: String, params: Dictionary = {}, interrupt: bool = true) -> void
func replay() -> void                   # replays _current_line_id with the same params
func stop() -> void
func has_audio(line_id: String) -> bool
func duration_of(line_id: String, params: Dictionary) -> float   # for UI timing, from manifest
```

Behaviour:

- `speak` is a no-op (except emitting `line_finished` immediately) when the profile's read-aloud setting is off, so callers never branch on the setting.
- Resolution: look up the line in the manifest; for each fragment, `file` → load `res://narration/audio/<file>`; `slot` → `params[slot]` → if `int` in 0..1000 play `numbers/<n>.ogg`; if `int` above 1000 split into thousands/hundreds (Zone 8 needs this later; for now log a warning and speak digit by digit); if `String` matching a phrase key play `phrases/<key>.ogg`; if a term ID play `terms/<id>.ogg`.
- Playback runs one `AudioStreamPlayer` on the `Voice` bus (the bus already exists in `default_bus_layout.tres`; `Music` ducks by −8 dB while voice plays via a tween on the bus volume).
- `word_spoken` is driven by a timer per fragment using the manifest word timings; number slots emit one `word_spoken` for the whole number.
- Speech bubbles (`scenes/shell/ui/speech_bubble.tscn`) connect to `word_spoken` and highlight the matching word with a `RichTextLabel` BBCode color span; they also show a replay button (64 dp minimum via `UI.min_target_px()`) that calls `Narration.replay()`.
- Preloading: on zone enter, call `Narration.preload_zone("z1")` to `ResourceLoader.load_threaded_request` the zone's clips (verify API name in Godot docs; it exists in 4.x). Keep memory under control by releasing the previous zone.
- Never use `DisplayServer.tts_speak` in child-facing code.

**Godot idiom notes for Spiro:** an *autoload* is a node Godot instantiates once at startup and keeps alive across scene changes, reachable by its name from any script. A *signal* is a typed event a node emits; other nodes connect a method to it instead of polling. An *audio bus* is a mixer channel; routing voice to its own bus lets the game lower music while Bolt talks.

### 3.4 `Text` autoload changes

`Text.get_line(id, params)` already returns display text. Add:

```gdscript
func word_list(id: String, params: Dictionary) -> PackedStringArray   # same tokenization the manifest uses
func is_narrated(id: String) -> bool                                   # context not parent_*
```

Tokenization must match `tools/voice/segmenter.py` exactly (split on whitespace after placeholder substitution; punctuation stays attached to the word). Share the rule as a documented spec in both files and test both against the same fixture list.

### 3.5 Profiles (`autoload/profiles.gd`, `scripts/save/`)

Up to four child profiles per device. Every per-child autoload (`Adaptive`, `Rewards`, session settings) reads and writes through the active profile.

```gdscript
class_name ProfileManager
extends Node

signal active_profile_changed(profile: Profile)
signal profiles_changed()

const MAX_PROFILES: int = 4

var active: Profile
func list() -> Array[Profile]
func create(nickname: String, avatar_id: String, starting_grade: int, read_aloud: bool) -> Profile
func select(profile_id: String) -> void
func delete(profile_id: String) -> void          # parent area only; asks twice
func rename(profile_id: String, nickname: String) -> void
```

`Profile` is a `Resource` in `scripts/core/profile.gd`:

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | `p_` + 8 random hex chars, generated once |
| `nickname` | `String` | first name or nickname only (the only personal data stored) |
| `avatar_id` | `String` | one of ~8 Bolt-themed icons; never a photo |
| `created_at`, `last_played_at` | `String` ISO date | for the lantern streak and parent summary |
| `read_aloud` | `bool` | default `true` when `starting_grade <= 1`, else `false`; Charlie's profile defaults `false` |
| `starting_grade` | `int` | K=0 … 6; drives generic placement |
| `interface_mode` | `String` | `explorer` for all Phase 3 profiles (Scholar arrives in Phase 4) |
| `session_minutes` | `int` | parent-set soft limit, default 20 |
| `handwriting_coaching` | `bool` | default `false` |

Save layout (atomic writes with `.tmp` → rename and `.bak`, as the MVP `SaveSystem` already does):

```
user://
  profiles/
    index.json                 # {schema_version, active_profile_id, profiles: [{id, nickname, avatar_id, ...}]}
    <profile_id>/
      adaptive.json            # BKT state, attempt log, review queue
      rewards.json             # coins, gems, inventory, badges, streak, family points
      settings.json            # per-profile settings above
      .bak copies of each
  settings.json                # device-wide parent settings (gate PIN hash, reward definitions)
```

**Migration from the single-profile MVP/1.0 save** (`scripts/save/migrations/migrate_N_to_N1.gd`, where `N` is the Version 1.0 schema): create `profiles/index.json` with one profile from the existing `user://save/profile.json` and `attempts.jsonl` (nickname from the existing `child.nickname` field, `read_aloud = false`, `starting_grade = 1`), move the adaptive/rewards sections into `profiles/<id>/`, keep the old file as `save.v<N>.bak`. Add `tests/save/fixtures/v<N>_single_profile.json` and extend the "load every fixture" test. Changing the save schema is on the "ask Spiro" list: raise it in Sprint 23 planning before writing the migration.

Cross-device export/import (Sprint 17) now exports one profile at a time; the export file carries `profile_id` and `nickname`, and import offers "replace this profile" or "add as new profile" (if under four).

### 3.6 Generic placement (`scripts/adaptive/placement.gd`)

Charlie's placement is seeded from his Star results. For other families, the parent picks a starting grade during profile creation, and the placement quest ("survey the mountain", about 10 minutes) adjusts from there.

- `placement.seed_from_grade(grade: int) -> Dictionary[String, float]`: returns BKT priors per skill. Table in `curriculum/placement_priors.json`: grade K → zone 1 skills prior 0.2; grade 1 → zone 1 prior 0.5, zone 2 prior 0.2; grade 2 → zones 1–2 prior 0.7, zone 3 prior 0.4; grade 3+ → zones 1–3 prior 0.85, zone 4 prior 0.5, zone 5 prior 0.3. Values are starting points; fitting them needs Spiro's sign-off (BKT defaults are on the ask list).
- The quest itself is unchanged from the MVP: it walks the frontier and updates priors from answers; it just starts from the grade seed instead of the Star seed.
- Simulated-learner tests: a grade-K random guesser placed at grade 3 must fall back to zone 1 frontier skills within 12 problems; a fast learner placed at grade K must reach zone 2 within the quest.

### 3.7 Parent area additions (`scenes/shell/parent_area/`)

- **Parent onboarding** on first run: three screens, each one picture plus two sentences. Set the gate, create the first profile (nickname, avatar, grade, read-aloud), set the session limit. Text lines live in the table with `context=parent_*`, so they're not narrated and `LineEdit` is allowed here for the nickname.
- **"How this game teaches" page** (`parent_area/how_it_teaches.tscn`): a static scrollable page explaining the skill map, mastery, spaced review and the hint ladder in parent language; links (as plain text, since there is no browser intent) to the privacy policy URL.
- **Profile switcher** on the title screen: up to four large avatar tiles (child-facing; tap to select; no text entry). Adding or deleting a profile is behind the gate.
- **Parental gate** review: the gate must be an adult-level task (e.g., "type the product of 7 and 8" using a `LineEdit`, or hold-and-answer), must not be defeatable by random tapping, and must not be a known pattern a child can memorise. Add a test that 1,000 random tap sequences never open it.

### 3.8 Broad device support

| Device class | Build | Input path | Test in |
|---|---|---|---|
| Charlie's ARM 2-in-1 (laptop/tent/tablet) | arm64-v8a | touch, pen, trackpad, keyboard | real device, every Friday |
| Charlie's Android tablet | arm64-v8a | touch, optional pen | real device |
| Intel/AMD Chromebooks | **x86_64** (new in Sprint 25) | touch or mouse | Android Studio emulator, x86_64 "Desktop" / ChromeOS-like profile |
| Mouse-only Chromebook | both | click, drag; `NumberPad` instead of `ChalkSlate` | emulator with no touch; also Windows editor run with `--no-touch` dev flag |
| Smaller tablets (8–10") | both | touch | emulator Pixel Tablet, 8" profile, 1280×800 |
| Older/low-end tablets | both | touch | emulator with 2 GB RAM, API = Godot minimum |

Design rules already in `CLAUDE.md` apply: landscape only; anchors and containers; 16:9, 16:10, 3:2 and 4:3; 64 dp targets; no multi-finger gestures; 60 fps.

**Mouse-only path.** `InputRouter` already maps mouse to the same actions. Phase 3 adds a capability check at startup: `DisplayServer.is_touchscreen_available()` (verify in Godot docs; present in 4.x) and whether the digit network's weights loaded (`DigitInk.is_available`; corrected 2026-10-19: recognition runs in GDScript, there is no plugin). Built as `DeviceCaps` (`scripts/input/device_caps.gd`). If no touchscreen, `ChalkSlate` is hidden from the answer-mode chooser and `NumberPad` is the default; drag targets grow their drop tolerance by 25%. Every screen must be completable with click and drag only (see Testing).

**Phones are supported** (Spiro, 2026-10-19; this replaces the earlier phone-exclusion plan). Both export presets keep every screen size on (`screen/support_small`, `support_normal`, `support_large`, `support_xlarge` all `true`), and no Play Console device catalog rule excludes phones. Layouts must fit a landscape phone (about 20:9, roughly 360 dp tall) with 64 dp targets: `tools/qa/capture_screens.tscn` captures two phone sizes too (`20x9`, 2400x1080 at 420 dpi, and `20x9_small`, 1600x720 at 320 dpi), and `tests/scenes/test_phone_layout.gd` checks every screen, every answer input, the hint states and the overlays at those phone metrics and at 16:9, 16:10, 3:2 and 4:3 (compact layouts: `UI.is_compact()`, `docs/decisions.md` "Phone layout pass"). `check_manifest.py` fails if anything shuts phones out.

The manifest must still contain **no `INTERNET` permission**. After each export, `python tools/ci/check_manifest.py build/gem-mines.aab` (new, uses `bundletool` or `aapt2` from the Android SDK) fails if `INTERNET`, `ACCESS_FINE_LOCATION`, `CAMERA`, `RECORD_AUDIO`, `READ_CONTACTS` or `com.google.android.gms.permission.AD_ID` appear. Keep this check in CI.

**Low-end performance.** Target 60 fps with the emulator's 2 GB profile: texture atlases for Zones 1–5 (Godot's import "atlas" option or a packed `AtlasTexture` set), OGG for all audio, no per-frame allocations in `_process` (profile with the Godot profiler; look for GC churn in the Monitors tab). Loading screens between zones instead of loading everything at title.

### 3.9 Compliance package (Sprint 24)

Everything here must describe what the app *actually does*; the privacy policy is verified against the build (see Testing).

| Artefact | Location | Content |
|---|---|---|
| Privacy policy | `docs/privacy-policy.md`, published via GitHub Pages at a stable URL that is also entered in Play Console | What is stored on the device (nickname, skill states, attempt history, inventory, settings); what is never collected (location, contacts, camera, microphone, advertising ID, accounts, analytics, handwriting images); that nothing leaves the device unless a parent exports a file; no ads; no purchases; no third-party SDKs that collect data; contact email; effective date; how a parent deletes data (delete the profile or uninstall). |
| Data safety form answers | `docs/compliance/data-safety.md` | "Does your app collect or share any of the required user data types?" → No. Document the reasoning per data type and note the GDScript digit reader (`scripts/input/`) processes strokes in memory only (corrected 2026-10-19: no `digit_ink` plugin, no LiteRT). |
| Target audience & content | `docs/compliance/target-audience.md` | Age groups 6–8 and 9–12; "designed for children"; no ads; no third-party ads SDKs; app meets Families Policy. |
| Content rating | `docs/compliance/content-rating.md` | IARC questionnaire answers: no violence, no user interaction/sharing, no purchases, no location. |
| SDK audit | `docs/sdk-audit.md` | One row per dependency: name, version, purpose, shipped in APK?, network?, data?, Families-Policy status. Expected rows: Godot engine, GdUnit4 (not shipped), `digit_ink` (own GDScript code, no plugin and no LiteRT since 2026-10-17, no network), font Andika (OFL), art/audio packs (licenses in `assets/CREDITS.md`). |
| Parental gate review | `docs/compliance/parental-gate.md` | Description of the gate, why it meets Google's guidance, test evidence. |
| Families Policy self-check | `docs/compliance/families-self-check.md` | Checklist walk-through of Google's current policy page, dated, with the policy version. Re-run every release. |
| AI voice disclosure | store listing text | Optional good practice: "Bolt's voice is a licensed AI voice." Also record the provider licence terms and the date checked in `docs/decisions.md`. |

### 3.10 Store listing and testing tracks

Assets (`marketing/` directory, gitignored except for the source `.svg`/`.kra` files under 2 MB; final PNGs under `marketing/export/` are committed because they are release artefacts):

| Asset | Spec (verify current Play Console limits) | Notes |
|---|---|---|
| App icon | 512×512 PNG, 32-bit | Bolt's headlamp on a gem; also the adaptive icon layers in the Godot export preset |
| Feature graphic | 1024×500 PNG | Mountain cross-section with zone colours |
| Screenshots | at least 4 for tablets, 16:10 and 16:9 | Dig loop, Chalk Slate, Museum, Parent dashboard (with a fictional profile, never Charlie's real data) |
| Short trailer | 30–60 s MP4, landscape | Screen capture from the emulator; music from the licensed pack |
| Short description | 80 chars | |
| Full description | up to 4,000 chars | Mentions: offline, no ads, no purchases, ages 6–12 (no read-aloud and no AI voice: there is no narration, Spiro 2026-10-19) |

Testing tracks:

- **Internal testing** (Charlie, Spiro, second observer): every Friday build, unchanged.
- **Closed testing** (Sprint 26): on a personal account, **12 or more opted-in testers for 14 consecutive days** are required before production access can be requested. An organization account is exempt but a closed test is still the plan for feedback. Recruit from school and friends in Sprint 25; collect feedback through a short form link in the tester email (not in the app, which has no network).
- **Production**: Sprint 28. Allow about 7 days or more for Google's review of a children's app.

## Sprint plan

### Sprint 22 (Apr 12–16): AI-voice narration

**Goal.** Bolt speaks. Every narrated line for Zones 1–5 plus numbers 0–1,000 has generated audio, the `Narration` autoload plays it with word highlighting and a replay button, and the whole thing is off by default for Charlie.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P3-S22-01 | `docs/voice-provider-shortlist` | Shortlist 2–3 providers; confirm each plan's licence allows commercial use in a distributed app, rights after cancellation, and training-data terms; record in `docs/decisions.md` | Decision entry written with date, choice, why, alternatives |
| P3-S22-02 | `feat/voice-pipeline` | `tools/voice/` package: providers, segmenter, numbers, postprocess, timing, manifest, `generate.py` with `--dry-run`, `--changed`, `--all --zone`, `--samples`, `--verify` | `pytest tools/voice` passes; `--dry-run` lists every Zone 1–5 line and a cost estimate |
| P3-S22-03 | `feat/voice-samples` | Generate 3 voice samples (5 lines each) with Spiro's approval of the paid call; Charlie picks Bolt's voice | Chosen `voice_id`/`model_id` pinned in `tools/voice/config.toml` and `docs/decisions.md` |
| P3-S22-04 | `feat/narration-manager` | `autoload/narration.gd`, `Voice` bus, music ducking, manifest loading, number splicing, `word_spoken` | GdUnit4 tests pass with a fixture manifest and silent OGG stubs |
| P3-S22-05 | `feat/speech-bubble-highlight` | Speech bubble highlights words from `word_spoken`; replay button; `Text.word_list` matches the segmenter | Highlight visually in sync on 10 sample lines on the tablet |
| P3-S22-06 | `content/voice-z1-z5` | Generate all Zone 1–5 lines, numbers 0–1000, phrases, terms (paid run, approved) | `generate.py --verify` exits 0; manifest committed; download size recorded |
| P3-S22-07 | `chore/ci-narration-coverage` | CI step: `--verify` plus stale-hash check, fails on missing or stale audio for narrated lines | CI red when a line is edited without regeneration |

Implementation notes for the agent:

- Build P3-S22-04 against a fixture manifest and three silent 0.3 s OGG files in `tests/fixtures/narration/` so tests never need real audio or the paid API.
- The segmenter and `Text.word_list` must agree; put the 20-line fixture in `tests/fixtures/tokenization.json` and test both sides against it (`pytest` and GdUnit4).
- Music ducking: tween `AudioServer.set_bus_volume_db(music_bus_idx, -8.0)` over 0.15 s on `line_started`, back to 0 dB on `line_finished`. Verify `AudioServer` method names in the docs.
- Charlie's profile keeps `read_aloud = false`; test that `speak()` is a no-op there and that the replay button is hidden when read-aloud is off (or shown and plays once on tap; Spiro decides, default hidden).
- Never commit API keys; `.env` is gitignored; the pipeline refuses to run a paid command without `--yes` **and** a visible cost estimate.

Tests:

- `tools/voice/tests/test_segmenter.py`: placeholders at start, middle, end, multiple slots, punctuation.
- `tools/voice/tests/test_postprocess.py`: ffmpeg command assembly (mock subprocess); loudness target constants.
- `tests/autoload/test_narration.gd`: resolution order, read-aloud off no-op, number out of range warning, replay.
- Manual: 10 lines on the tablet, word highlight within ±100 ms of the audio.

Playtest focus: Charlie hears Bolt for the first time. Does he like the voice? Does he turn read-aloud on or off himself?

### Sprint 23 (Apr 19–23): Families who aren't us

**Goal.** A device supports up to four child profiles with a per-profile read-aloud setting, a generic placement seeded from a parent-chosen grade, parent onboarding and a "how this game teaches" page.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P3-S23-01 | `feat/profiles-autoload` | `Profile` resource, `Profiles` autoload, `user://profiles/` layout, atomic saves | GdUnit4 tests for create/select/delete/rename, max 4 |
| P3-S23-02 | `feat/save-migration-profiles` | Migration from single-profile save; fixture for Version 1.0 schema; "ask Spiro" sign-off recorded | All fixtures load; old save becomes profile 1 with identical skill state |
| P3-S23-03 | `refactor/per-profile-state` | `Adaptive`, `Rewards`, session timer and streak read/write through `Profiles.active` | Switching profiles swaps state with no leakage (test) |
| P3-S23-04 | `feat/profile-switcher` | Title-screen avatar tiles; add/delete behind the gate | Child can switch with one tap; mouse-only works |
| P3-S23-05 | `feat/read-aloud-setting` | Per-profile toggle in parent area and in the pause menu (picture toggle); default by grade | `Narration` follows the active profile immediately |
| P3-S23-06 | `feat/generic-placement` | `placement_priors.json`, `seed_from_grade`, quest starts from grade seed | Simulated-learner tests for placement pass |
| P3-S23-07 | `feat/parent-onboarding` | Three-screen onboarding; gate setup; first profile creation | New install reaches the hub in under 2 minutes with no reading by the child |
| P3-S23-08 | `content/how-it-teaches` | Parent-facing page in the parent area | Reviewed by Spiro; linked privacy URL text |

Implementation notes for the agent:

- Godot idiom: a `Resource` is a data object Godot can serialize; keep `Profile` free of node references so it can be unit-tested and saved as JSON through `SaveSystem`.
- Per-profile state swap: `Profiles.select()` must `await` the previous profile's save before emitting `active_profile_changed`; autoloads reload on that signal. Add a save point on profile switch.
- Export/import (Sprint 17) is now per profile: update `parent_area/export.tscn` with a profile picker.
- Child-facing onboarding strings go in `text/lines.csv` (narrated); parent-facing ones use `context=parent_*`.
- Deleting a profile is the only destructive action in the app: two confirmations in the parent area, and the files are moved to `user://trash/<id>-<timestamp>/` for 30 days before deletion on the next launch.

Tests:

- `tests/autoload/test_profiles.gd`, `tests/save/test_migrations.gd` (every fixture), `tests/adaptive/test_placement.gd`.
- Posture-switch and app-pause save points still fire with profiles (regression).

Playtest focus: Charlie creates a second profile for a stuffed animal and switches back; does his progress stay intact? A second adult walks through onboarding cold.

### Sprint 24 (Apr 26–30): Compliance

**Goal.** Every document and setting Google will ask for exists, matches the build, and is checked by a script where a script can check it.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P3-S24-01 | `docs/privacy-policy` | `docs/privacy-policy.md`; GitHub Pages site; URL recorded in `docs/decisions.md` | Page loads publicly at the stable URL |
| P3-S24-02 | `docs/data-safety` | Data safety form answers with reasoning per data type | Reviewed against the manifest check output |
| P3-S24-03 | `docs/target-audience-content-rating` | Target audience 6–8 and 9–12; IARC answers | Drafted and saved in Play Console as well |
| P3-S24-04 | `docs/sdk-audit` | Complete `docs/sdk-audit.md` with every dependency | No dependency in `addons/`, `android/`, `project.godot` is missing from the table (CI script `tools/ci/check_sdk_audit.py`) |
| P3-S24-05 | `feat/parental-gate-review` | Gate hardening; random-tap test; documentation | `docs/compliance/parental-gate.md` written; test passes |
| P3-S24-06 | `chore/manifest-check` | `tools/ci/check_manifest.py` in CI on every export | CI fails on any banned permission |
| P3-S24-07 | `docs/families-self-check` | Dated checklist against Google's current Families Policy page | Every item has evidence or a linked backlog item |

Implementation notes for the agent:

- Read `CLAUDE.md` rule 2 before writing the policy: the policy must say handwriting strokes are discarded after recognition and nothing is uploaded. If any code path contradicts this, that is a bug to fix, not a sentence to change.
- `check_manifest.py` uses `bundletool dump manifest --bundle build/gem-mines.aab` (bundletool JAR path from an env var) or `aapt2 dump badging` for APKs. Parse permissions; also assert `android:largeScreens`/`requiresSmallestWidthDp` once phone exclusion is in (Sprint 25).
- Keep the policy's effective date and version in the file header; the parent area shows the version string so support requests can reference it.

Tests:

- `tools/ci/tests/test_check_manifest.py` with a fixture manifest dump containing `INTERNET` (must fail) and a clean one (must pass).
- `tests/shell/test_parental_gate.gd`: 1,000 random sequences never open it; the correct answer opens it.

Playtest focus: none for Charlie; the second adult reviews the privacy policy for plain language.

### Sprint 25 (May 3–7): Broad device support

**Goal.** The game runs well on other families' hardware: x86_64 Chromebooks, mouse-only devices, small and older tablets, and Android phones (supported, Spiro 2026-10-19). Tester families are recruited.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P3-S25-01 | `chore/x86_64-build` | Add x86_64 to the export preset ABIs (ask Spiro; export settings change) | AAB contains arm64-v8a and x86_64; installs on the x86_64 emulator |
| P3-S25-02 | `feat/mouse-only-path` | Capability detection; hide `ChalkSlate` without touch; drop-tolerance; cursor feedback on drags | Every screen completed with mouse only (checklist in Testing) |
| P3-S25-03 | `fix/small-tablet-layout` | Layout fixes at 1280×800 8" and 4:3; target sizes still ≥ 64 dp | Screenshots per screen at 4 aspect ratios reviewed |
| P3-S25-04 | `perf/low-end` | Atlases, loading screens, no hot-path allocations; profile on 2 GB emulator | 60 fps in the dig loop and hub on the low-end profile |
| P3-S25-05 | `feat/phone-layouts` | Phones are supported (Spiro, 2026-10-19): every screen size on in the presets; layouts fit a landscape phone | Phone emulator installs and every screen fits; `check_manifest.py` fails if phones are shut out |
| P3-S25-06 | `chore/emulator-matrix` | Document and script the emulator profiles (`tools/ci/emulators.md`, AVD creation commands) | A fresh machine can recreate the matrix |
| P3-S25-07 | (no code) | Recruit tester families: 12+ if personal account, 3–5 otherwise; prepare the tester email and feedback form | Tester list with opted-in Google accounts ready for Sprint 26 |

Implementation notes for the agent:

- Godot's Android export preset has an "Architectures" section; enabling x86_64 roughly doubles native library size. Record the download size before and after in `docs/decisions.md` and check the 150 MB budget.
- Mouse-only: do not fork scenes. `InputRouter` already unifies input; the only differences are the capability flags and the answer-mode chooser. Add a dev flag `--no-touch` (read via `OS.get_cmdline_user_args()`; verify in docs) so the Windows editor can simulate it.
- Texture atlases: prefer Godot's import-time atlas option for sprite sheets over a hand-made packer; a dependency for packing would need Spiro's approval.

Tests:

- Automated: layout smoke test that instantiates every scene at four viewport sizes and asserts no interactive control is smaller than `UI.min_target_px()` (GdUnit4, headless).
- Manual: full session on each emulator profile; airplane mode on the real tablet.

Playtest focus: Charlie plays on the x86_64 emulator with a mouse only (novel for him): where does he reach for the screen?

### Sprint 26 (May 10–14): Store listing and closed test

**Goal.** The listing is complete and the closed test starts (and, on a personal account, runs 14 consecutive days without interruption).

| ID | Branch | Item | Done when |
|---|---|---|---|
| P3-S26-01 | `content/store-assets` | Icon, feature graphic, screenshots, trailer, descriptions (no AI-voice note: no narration, Spiro 2026-10-19) | All assets uploaded and the listing saves without errors |
| P3-S26-02 | `chore/release-build-rc1` | Release-signed AAB from CI; keystore via env vars; `check_manifest.py` green | Build uploaded to the closed track |
| P3-S26-03 | (Play Console) | Create closed testing track, add tester emails or group, publish the test; note the start date | 12+ testers opted in (personal) by day 1 |
| P3-S26-04 | `docs/tester-guide` | One-page tester guide: install steps, what to try, how to send feedback (form link), reminder that no data leaves the device | Sent with the invitation |
| P3-S26-05 | `feat/feedback-helper` | Parent-area "Copy diagnostics" button that puts app version, device model, profile count and last 20 non-personal log lines on the clipboard (no network; parent pastes it into the form) | Clipboard text contains no nickname or attempt data |

Implementation notes for the agent:

- Screenshots and the trailer use a **fictional profile** named "Sam"; never Charlie's data or `private/`.
- The release build is reproducible from CI: `"$GODOT" --headless --path . --export-release "Android" build/gem-mines.aab` with `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `..._USER`, `..._PASSWORD` environment variables (verify the exact variable names in the Godot export docs).
- Diagnostics text is parent-facing and uses the clipboard API `DisplayServer.clipboard_set()` (verify); it must exclude anything from the attempt log.

Tests:

- Install the closed-track build on both of Charlie's devices over the Version 1.0 save; verify the migration ran and profiles exist.
- `tests/shell/test_diagnostics.gd`: output contains no profile nickname and no attempt entries.

Tester focus: first-time onboarding by a parent who has never seen the game; read-aloud with a non-reading child.

### Sprint 27 (May 17–21): Closed-test fixes

**Goal.** Act on the first week of tester feedback with a mid-test build, without breaking the 14-day continuity.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P3-S27-01 | `fix/closed-test-batch-1` | Triage all feedback into the GitHub Projects board; fix crashes and onboarding blockers first | Zero open crash reports |
| P3-S27-02 | `fix/read-aloud-gaps` | Any screen a non-reader could not pass with read-aloud on | Second no-reading walkthrough passes |
| P3-S27-03 | `content/text-fixes` | Line text fixes from feedback; regenerate changed audio (paid, approved) | `--verify` green; no stale lines |
| P3-S27-04 | `chore/release-build-rc2` | Mid-test build to the closed track | Testers receive the update; the test continues uninterrupted |

Implementation notes for the agent:

- A text change touches `text/lines.csv` only; the pipeline bumps `voice_version`. Never edit the manifest by hand.
- Save migrations: if a fix needs a schema change, it needs a migration, a fixture and Spiro's sign-off, even mid-test.

Tests:

- Full regression: GdUnit4 suites, cross-check, lint, manifest check, emulator matrix smoke run.
- Update-over-old-save on both real devices.

Tester focus: did the first-week issues go away? Did any family stop playing, and why?

### Sprint 28 (May 24–28): Launch

**Goal.** Final build submitted for production.

| ID | Branch | Item | Done when |
|---|---|---|---|
| P3-S28-01 | `fix/closed-test-batch-2` | Remaining feedback fixes that fit the week | Board has no "launch blocker" cards |
| P3-S28-02 | `chore/release-build-1.0.0` | Version `1.0.0`, version code bumped, release notes | Tagged `v1.0.0` in git; AAB archived with its mapping and checksum |
| P3-S28-03 | (Play Console) | Personal account: request production access after the 14-day test completes (earliest end: Sprint 26 start + 14 days). Organization: submit directly. Complete the target-audience, data-safety and content-rating sections from the Sprint 24 docs | Submitted; review in progress |
| P3-S28-04 | `docs/release-checklist` | `docs/release-checklist.md` capturing exactly what was done, for Phase 4 content updates | Checklist reusable without reading this doc |
| P3-S28-05 | `docs/phase-3-retro` | Retro note in `docs/decisions.md`: what tester families taught us, open backlog | Written before Phase 4 planning |

Implementation notes for the agent:

- Google's review of a children's app can take 7 days or longer; the public milestone date is "early June, after review." Do not plan Phase 4 work that depends on the public listing being live.
- Keep the internal track on the same build as production so Charlie's devices match what families get.

Tests: final regression as in Sprint 27, plus a fresh-install airplane-mode session on each real device.

Playtest focus: Charlie's regular weekend session on the release build; no changes to his routine.

## Testing and quality

| Check | How | Where it runs |
|---|---|---|
| **Narration coverage** | `python tools/voice/generate.py --verify`: every row with a narrated `context` has every fragment file, every number 0–1000 and phrase has a file, and `sha1(text) == text_hash` for all narrated rows. Any miss exits 1. | CI on every PR; release builds blocked on failure |
| **Read-aloud, no-reading walkthrough** | A checklist of every child-facing screen (title, profile switcher, hub, dig, hint ladder steps 1–4, Chalk Slate confirmation, museum, workshop, builds, wind-down, pause). An adult covers all text with a card and completes a session using only pictures and audio. | Manual, Sprints 22, 23, 27 |
| **Word highlighting sync** | 10 sampled lines per zone; highlight within ±100 ms by eye against the audio; automated test compares manifest timings to clip durations (sum of word spans ≤ duration + 50 ms) | Automated in CI; manual per zone batch |
| **Multi-profile saves** | GdUnit4: create 4 profiles, play simulated attempts in each, switch, close mid-dig, reopen: each profile's BKT state and rewards are unchanged and distinct. Migration fixtures from every schema version load. Delete goes to trash and restores. | CI |
| **Mouse-only pass** | Every screen completed with click and drag only (x86_64 emulator without touch and Windows editor `--no-touch`); `ChalkSlate` never appears | Manual, Sprint 25 and every release |
| **Keyboard-only pass** | Every screen reachable with Tab/Enter/arrows in laptop posture (focus neighbours set on all controls) | Manual, Sprint 25 and every release |
| **Touch-only and stylus-only passes** | Unchanged from Phase 2 | Every Friday |
| **Layout smoke test** | `tests/scenes/test_phone_layout.gd` (`LayoutAudit`): every screen and answer input at 1920×1080, 1920×1200, 1620×1080, 1440×1080 and two landscape phones (2400×1080 @ 420 dpi, 1600×720 @ 320 dpi, via `TestWindow.use_phone`); every visible tappable control is on screen, ≥ `UI.min_target_px()` and overlaps no other | CI, headless |
| **Airplane-mode session** | Full 20-minute session with Wi-Fi off on each real device and the x86_64 emulator; also confirm install works with no data connection after download | Manual, every release |
| **Permissions** | `tools/ci/check_manifest.py` on every exported AAB/APK | CI |
| **Privacy policy matches behaviour** | Checklist in `docs/compliance/policy-verification.md`: for each sentence in the policy, the evidence (manifest dump, code path, test name). Re-run when the policy or the manifest changes. | Manual, Sprint 24 and before every store submission |
| **Parental gate** | 1,000 random tap/click sequences never open it; correct input opens it; it cannot be bypassed by back navigation | CI |
| **Math, adaptive, lint** | Unchanged: GdUnit4, cross-check 10,000 per generator, simulated learners, `lint_content.py` | CI |
| **Performance** | 60 fps on the 2 GB emulator profile in the dig loop and hub; download size under 150 MB with x86_64 included | Sprint 25 and every release |

## Exit criteria

Phase 3 is complete when all of these hold:

1. **Public Version 1.0 is live on Google Play** for the declared age groups (6–8 and 9–12), after Google's children's-app review, with the same build on the internal track.
2. Narration coverage is 100% for Zones 1–5, numbers and phrases; a non-reading child can complete a session with read-aloud on (walkthrough passed twice).
3. Up to four profiles work; Version 1.0 saves migrated on both of Charlie's devices with no loss.
4. The AAB includes arm64-v8a and x86_64, supports phones, requests no `INTERNET` or other banned permission, and installs on the full emulator matrix.
5. Every screen passes touch-only, stylus-only, mouse-only and keyboard-only passes.
6. Privacy policy, data safety form, target audience, content rating, SDK audit, parental-gate review and Families self-check are complete and consistent with the build.
7. The closed test ran (14 consecutive days with 12+ testers on a personal account) and all launch-blocker feedback is fixed.
8. `docs/release-checklist.md` exists and was used for the 1.0.0 submission.
9. CI is green on `main`, tagged `v1.0.0`.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Voice provider licence doesn't clearly allow distribution, or terms change | Low–Medium | High | Confirm commercial terms in writing before generating (P3-S22-01); keep all audio in the repo; pinned voice ID; provider adapters make switching a re-generation, not a rewrite |
| Google's review rejects or delays the app | Medium | High | Compliance designed in from day one; Sprint 24 is dedicated; manifest check in CI; allow 7+ days; have the organization-account route documented |
| Fewer than 12 testers on a personal account | Medium | High (blocks production) | Start recruiting in Sprint 25; organization account is exempt; keep a reserve list |
| Narration audio pushes the download over 150 MB | Low | Medium | OGG quality 4 mono; per-zone measurement; number clips shared across zones; drop x86_64 only as a last resort (ask Spiro) |
| Word highlighting drifts on devices with audio latency | Medium | Low | Use playback position (`get_playback_position()` plus `AudioServer.get_time_since_last_mix()`; verify in docs) rather than wall-clock timers |
| Profile migration breaks an existing save | Low | High | Fixture per schema version; test on both real devices before the closed track; `.bak` retained |
| Mouse-only path exposes drag targets too small or too precise for a 6-year-old | Medium | Medium | Drop tolerance increase; layout smoke test; tester-family feedback in Sprint 26 |
| A tester family's device is far slower than the emulator profiles | Medium | Medium | Low-end profile in Sprint 25; diagnostics clipboard helper to learn the device model |
| Charlie dislikes the chosen voice after the full batch | Low | Medium | He votes on samples before the paid batch; keep the two runner-up voice IDs in `docs/decisions.md` |

## Decisions for Spiro

1. **Voice provider and licence.** Recommendation: pick the provider whose paid plan states commercial use in distributed apps, retained rights after cancellation and acceptable training-data terms; record the exact terms and date. Shortlist ElevenLabs, OpenAI TTS, Google Cloud TTS and Azure AI Speech per the master plan. Never clone a real person's voice.
2. **Bolt's voice.** Charlie chooses from three samples (same five lines each). Recommendation: present them blind and let him pick twice on different days; go with the consistent choice.
3. **Read-aloud defaults.** Recommendation: on by default for `starting_grade <= 1`, off for Charlie's profile, always toggleable in the pause menu with a picture toggle.
4. **Pricing.** Options: free; paid upfront; free with a one-time "unlock the deep mountain" purchase (still no ads, no loot boxes). Recommendation for the 1.0 launch: **free**, which keeps the data-safety and content-rating answers simplest and removes a purchase flow from the children's-app review; revisit at Phase 4 when Zones 6+ ship.
5. **Account type consequences.** If the organization account from Sprint 1 is verified, submit directly in Sprint 28 and still run the closed test for feedback. If on a personal account, the 14-day closed test with 12+ testers is on the critical path: it must start no later than May 11 to finish by May 25.
6. **Phones and x86_64.** Decided 2026-10-19: phones are supported (no exclusion); include x86_64 unless the download exceeds 150 MB.
7. **AI-voice disclosure in the listing.** Recommendation: include the one-line note; it costs nothing and matches the plan's "good practice" advice.
8. **Save schema change for profiles** (Sprint 23) needs explicit sign-off before the migration is written.

## Hand-off to Phase 4

Phase 4 ships Zones 6–9 as free content updates using a three-sprint pattern per zone. Phase 3 leaves these reusable pieces in place:

**Three-sprint pattern (per zone):**

1. **Curriculum and generators.** Skill JSON in `curriculum/skills/zNN_*.json` (DAG test passes), generators in `scripts/generators/` with seeded GdUnit4 tests, independent Python checker in `tools/crosscheck/`, text lines added to `text/lines.csv` (not yet narrated), math-reviewer sign-off in `docs/decisions.md`.
2. **New mechanic and engineering project.** Scenes under `scenes/zones/zNN_*/`, build screen under `scenes/workshop/builds/`, playtest with Charlie.
3. **Art, voice batch, integration, polish, release.** Art pass with `assets/CREDITS.md` entries; `python tools/voice/generate.py --dry-run` then `--changed` (approved paid run) for the zone's lines; `--verify` green; polish; release through the checklist below.

**Content-update release checklist** (`docs/release-checklist.md`, written in Sprint 28; Phase 4 reuses it verbatim):

1. `main` green: import, GdUnit4, `pytest tools`, cross-check for touched generators, `lint_content.py`, narration `--verify`, layout smoke test.
2. Save schema: any change has a migration, a fixture and Spiro's sign-off; update-over-old-save tested on both real devices.
3. Export: version name and code bumped; release AAB from CI; `check_manifest.py` green; download size recorded and under 150 MB.
4. Device passes: touch-only, stylus-only, mouse-only, keyboard-only on the emulator matrix; airplane-mode session on both real devices; all three 2-in-1 postures.
5. Compliance: no new dependency without an `docs/sdk-audit.md` row; privacy policy still matches behaviour; Families self-check re-run if anything in the listing changed.
6. Store: release notes in parent language; new screenshots only if screens changed (fictional profile); upload to internal track first, then production.
7. Tag `vX.Y.Z`; archive the AAB and checksum; add a `docs/decisions.md` entry with the date and what shipped.
8. Charlie's devices updated from the internal track the same Friday.

Open items handed to Phase 4 planning: BKT priors for generic placement are literature defaults until tester-family logs exist; Scholar mode part 1 (Sprint 37) will need a keyboard-first answer mode that `InputRouter` already anticipates; the yearly target-API update (Sprint 38) reuses the manifest check and release checklist.
