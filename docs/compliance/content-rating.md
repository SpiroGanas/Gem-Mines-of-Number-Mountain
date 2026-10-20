# Content rating: IARC questionnaire answers (P3-S24-03)

Drafted 2026-10-19 from the game as built (Zones 1-5) and the content rules in `CLAUDE.md`. **Spiro:** fill in the IARC questionnaire in Play Console (App content > Content ratings) with these answers; the questionnaire's wording and order change, so answer each question as worded on the day. Record the date and the ratings issued here: ____.

**Category:** Game (the presets set `package/app_category=2`, Godot's "Game"). If the questionnaire offers "Educational" as a game type, choose it.

| Topic | Answer | Evidence in the game |
|---|---|---|
| Violence (realistic, fantasy, cartoon, blood, against characters or animals) | **No** | The child breaks rocks and boulders with a pickaxe to find gems; no characters or creatures are hurt. A rock "cracks"; nothing else is ever struck |
| Fear, horror, frightening content | **No** | The mine is lit by electric lamps and glowing crystals; no dark or scary scenes, no monsters |
| Sexuality, nudity | **No** | |
| Language (profanity, crude humour) | **No** | All text is in `text/lines.csv`, written for a first-grade reader; Bolt is never sarcastic or mocking |
| Controlled substances (alcohol, tobacco, drugs) | **No** | Banned by the content rules and by `tools/ci/lint_content.py`'s banned-keyword check |
| Gambling (real or simulated), gambling-like mechanics | **No** | No loot boxes, spinners or chance-based rewards; rare gems come from rare *numbers*, which is deterministic (`CLAUDE.md` rule 9) |
| Users can interact or exchange content (chat, sharing) | **No** | No network, no accounts, no chat, no user-generated content shared with anyone |
| Shares the user's location with other users | **No** | No location access |
| Digital purchases, in-app purchases | **No** | Free, no purchases |
| Unrestricted internet access, a web browser | **No** | No `INTERNET` permission; no links |
| Collects personal information that could be shared | **No** | `docs/compliance/data-safety.md` |

**Expected result:** the lowest rating everywhere (ESRB Everyone, PEGI 3, USK 0, ClassInd L, ACB General / G). If any rating comes back higher, write down which answer caused it before changing anything.
