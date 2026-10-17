# Narration audio (Phase 3)

`narration/audio/` is **generated** by `tools/voice/generate.py` from `text/lines.csv`. Never hand-edit files here. Numbers 0–1,000 and phrase fragments are generated once and spliced at runtime by the `Narration` autoload. Generation calls a paid API: ask Spiro before running it without `--dry-run`.
