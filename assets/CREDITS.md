# Asset credits and licenses

Every file under `assets/` needs an entry here before it is committed. Record the source, author, license and the URL it came from. Placeholder art for the MVP comes from CC0 packs (for example Kenney.nl). The Andika font is under the SIL Open Font License. Commissioned art (Bolt and key art, Phase 2) is recorded with the contract reference.

| Path | What | Source / author | License | Notes |
|---|---|---|---|---|
| `/icon.svg` | Placeholder app icon (gem) | Project-drawn | Project | Replace with commissioned icon in Phase 3 |
| `assets/art/placeholder/rock_idle.svg` | Placeholder rock (Sprint 1 hello rock) | Project-drawn | Project | Replaced by the CC0 art pass in Sprint 10 |
| `assets/art/placeholder/rock_cracked.svg` | Placeholder cracked rock with a gem | Project-drawn | Project | Same |
| `assets/sfx/placeholder/rock_crack.ogg` | Placeholder crack sound (synthesized noise burst and thump, OGG Vorbis q4) | Project-generated | Project | Replaced by a licensed SFX pack in Sprint 4 |

## Selected sources (chosen in Sprint 2; nothing below is imported yet)

These are the sources the placeholder art direction (`docs/gdd.md` section 8) points at. **No file from them is in the repository.** Each file gets its own row in the table above when it is imported (planned for the Sprint 10 art pass; the Andika import waits for Spiro's approval in `docs/sdk-audit.md`). Pack contents were not checked from the build environment, which cannot reach these sites, so confirm each pack on download.

| Source | What it would supply | License | Status |
|---|---|---|---|
| Kenney (kenney.nl): UI, icon and platformer-style packs | Buttons, panels, icons, rock and gem sprites | CC0 1.0 (public domain) | Pack names to be confirmed by Spiro on download |
| Kenney (kenney.nl): interface, impact and UI audio packs | Replace the project-made placeholder SFX | CC0 1.0 | Same |
| Andika (SIL International) | Child-facing text font | SIL Open Font License 1.1 | Awaiting approval (`docs/sdk-audit.md`) |
