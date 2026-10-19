# Parental gate review (P3-S24-05)

Drafted 2026-10-19 from the gate as built. Phase 3 hardens the gate in parallel work (a random-tap test and any changes it leads to); **re-read this page against `scenes/shell/parent_area/parent_gate.gd` and `scripts/core/parent_gate_rules.gd` before each store submission** and update the description if they changed.

## What the gate protects

Everything for grown-ups is behind it: the parent dashboard (skill map, weekly summary, session length, nickname, re-running placement), family rewards, handwriting on/off, **progress export and import** (the only way data leaves the device; `docs/privacy-policy.md`), the import/export log and, from Phase 3, adding and deleting child profiles. There are no purchases, ads or links out of the app to protect.

## How it works

- A grown-up taps "Grown-ups" on the hub (`ui.hub.grownups`). The gate screen asks a multiplication question: a two-digit number times a one-digit number (12-99 times 3-9, so answers 36-891), picked at random each visit (`ParentGateRules.new_question`).
- The answer is typed on the game's `NumberPad` (up to three digits) and checked when Go is pressed.
- A wrong answer shows "That is not it. Here is a new one." (`parent.gate.missed`) and a **new** question, so answers cannot be learned by heart.
- **Three wrong answers lock the gate for 30 seconds** (`MAX_MISSES = 3`, `COOLDOWN_MS = 30000`). The pad sleeps; no countdown is shown, so there is nothing to watch or race.
- The lock and the miss count are remembered across visits (static state on the screen), so leaving and coming back does not reset them (peer review 02, issue 4).
- Back returns to the hub. Android's back gesture never passes the gate: the gate is not a pausable screen, and the only way forward is `ParentGateRules.Result.PASSED`, which opens the dashboard.

## Why it meets Google's guidance

Google asks that a gate in a children's app is something a child is unlikely to pass, that does not depend on knowing a fixed secret a child could see once, and that is not passable by random tapping.

- **Adult-level task:** two-digit-by-one-digit multiplication is a grade 3-4 skill done in the head; the gate is aimed at the game's younger players. **Known limit:** a strong 9-12 year old (the game's older audience, and a gifted younger player who has finished Zone 4) can answer it. That is the common trade-off for math gates; for this app the gate protects settings and a file export, not purchases or links. **Spiro to decide** whether that is enough, or whether a harder or hold-and-answer task is wanted for the public release (the Phase 3 plan, section 3.7, allows either).
- **Not memorisable:** a fresh random question each visit and after every miss.
- **Not passable by random tapping:** a random entry matches the answer with probability about 1 in 900 per try (the answer is one specific number from 36 to 891). With three tries per 30 seconds, a child tapping at random would need, on average, over two hours of continuous tapping. The automated test (below) checks the gate never opens for random input.

## Test evidence

- `tests/core/test_parent_gate_rules.gd`: the question range, a pass, a miss bringing a new question, the lock after three misses and its end.
- `tests/scenes/test_parent_area.gd` and `tests/scenes/test_shell.gd`: the gate screen opens the dashboard only on a pass; Back goes to the hub; the lock survives leaving and returning.
- Phase 3 adds a random-input test (1,000 random tap or entry sequences never open the gate; the correct answer opens it), in `tests/` alongside the above. Record its file name and result here when it lands: ____.

Record the run (date, GdUnit4 totals) before each submission: ____.
