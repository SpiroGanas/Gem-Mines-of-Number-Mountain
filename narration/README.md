# Narration (none)

The game has **no narration and no AI voice** (Spiro's decision, 2026-10-19, `docs/decisions.md`): the children it is for read, and the text table (`text/lines.csv`) keeps every word in one place for review. There is no `Narration` autoload and no `tools/voice/` pipeline; `lines.csv` keeps its unused `voice_version` column only to avoid churning every row.

`narration/audio/` is kept empty on purpose (a `.gitkeep`) so the decision stays visible next to the plan documents that still describe the dropped voice sprints. Nothing reads this folder.
