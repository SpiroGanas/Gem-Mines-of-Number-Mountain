# Target audience and content (P3-S24-03)

Drafted 2026-10-19. **Spiro:** enter these in Play Console (App content > Target audience and content) and save the draft; record the date here: ____.

| Play Console question | Answer | Notes |
|---|---|---|
| Target age groups | **6-8** and **9-12** | Explorer mode is written for about 5-8 (`CLAUDE.md`, "Writing child-facing text"); the curriculum runs to number theory for older children. "5 and under" is **not** selected: the text assumes a reader, and there is no narration (Spiro, 2026-10-19). Selecting any child age group makes the whole app subject to the Families Policy |
| Could the app unintentionally appeal to children? | Not asked (children are the declared audience) | |
| Store presence: "designed for children" / Families | Yes: the app is made for children and families | Shown to parents in the Kids tab only after review |
| Does the app contain ads? | **No** | No ads SDK (`docs/sdk-audit.md`); no ad permission (`AD_ID` banned by `tools/ci/check_manifest.py`) |
| In-app purchases | **None** | Free app, no purchases (Spiro, plan recommendation accepted 2026-10-19); no billing library |
| Teacher Approved | Not applied for at launch | Optional; Google invites apps. Revisit after launch |
| Families Policy | Meets it; see `docs/compliance/families-self-check.md` | |

## What a parent will see

- The listing (`marketing/listing.md`) says: ages 6-12, works offline, no ads, no purchases, no accounts.
- The app opens on the title screen; the parent area is behind the parental gate (`docs/compliance/parental-gate.md`).
- Up to four child profiles per device (Phase 3, built in parallel; see `docs/phases/phase-3-public-release-readiness.md` 3.5): a nickname, a picture from the game's set and a starting grade. Adding or deleting a profile is behind the gate.

## Things that would change these answers

- Adding narration for non-readers might justify adding "5 and under" later (out of scope: no narration, Spiro 2026-10-19).
- Any purchase or "unlock" (Phase 4 pricing question) changes the purchases answer and needs the gate in front of it.
