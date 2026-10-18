# Draw calls per screen (Version 1.0)

Written by `tools/qa/capture_screens.tscn` on 2026-10-17 with the opengl3 renderer (llvmpipe (LLVM 20.1.2, 256 bits)). Draw calls depend on the scene, not the GPU, so they hold on the devices too; frame times must be measured on the devices (`docs/qa/perf-1.0.md`).

| Ratio | Screen | Draw calls | Objects |
|---|---|---|---|
| 16x9 | title | 15 | 41 |
| 16x9 | hub | 91 | 224 |
| 16x9 | mine | 61 | 164 |
| 16x9 | crafting | 57 | 231 |
| 16x9 | build_site | 62 | 210 |
| 16x9 | museum | 78 | 128 |
| 16x9 | badges | 58 | 227 |
| 16x9 | glossary | 71 | 354 |
| 16x9 | garage | 51 | 222 |
| 16x9 | settings | 34 | 76 |
| 16x10 | title | 15 | 41 |
| 16x10 | hub | 91 | 224 |
| 16x10 | mine | 63 | 160 |
| 16x10 | crafting | 57 | 231 |
| 16x10 | build_site | 62 | 210 |
| 16x10 | museum | 78 | 128 |
| 16x10 | badges | 58 | 227 |
| 16x10 | glossary | 77 | 390 |
| 16x10 | garage | 51 | 222 |
| 16x10 | settings | 34 | 76 |
| 3x2 | title | 15 | 41 |
| 3x2 | hub | 91 | 224 |
| 3x2 | mine | 64 | 159 |
| 3x2 | crafting | 57 | 231 |
| 3x2 | build_site | 62 | 210 |
| 3x2 | museum | 78 | 128 |
| 3x2 | badges | 58 | 227 |
| 3x2 | glossary | 77 | 390 |
| 3x2 | garage | 51 | 222 |
| 3x2 | settings | 34 | 76 |
| 4x3 | title | 15 | 41 |
| 4x3 | hub | 91 | 224 |
| 4x3 | mine | 61 | 152 |
| 4x3 | crafting | 57 | 231 |
| 4x3 | build_site | 62 | 210 |
| 4x3 | museum | 78 | 128 |
| 4x3 | badges | 58 | 227 |
| 4x3 | glossary | 75 | 388 |
| 4x3 | garage | 51 | 222 |
| 4x3 | settings | 34 | 76 |
