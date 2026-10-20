# Curriculum data guide (for the math reviewer)

You do not need to read code. This guide shows where the curriculum lives, how to read it, and how to look at real generated problems. Proposed changes go to Spiro; some need his sign-off first (section 2).

## 1. What a skill is

A **skill** is one small thing a child can learn, such as "add a Caesar shift to a word". Skills are listed zone by zone in `curriculum/skills/zNN_*.json`. Each record has:

| Field | Meaning |
|---|---|
| `id` | Stable name `topic.subtopic.action`, e.g. `mod.add.wrap`. Never renamed. |
| `name` | The parent-facing name. |
| `prereqs` | Skills that must be mastered first. |
| `generator`, `params` | The program that makes problems and its settings (ranges, modes). |
| `representations` | How it is shown, in the order a child meets them: **concrete** (a picture to act on), **pictorial** (a picture to read), **abstract** (numbers and words). |
| `answer_modes` | tap, drag, number_pad or keyboard (Scholar mode). |
| `terms` | Word Gems (vocabulary) used. |
| `misconceptions` | The named mistakes this skill's wrong answers may come from. |

## 2. Prerequisites

A skill is offered only when all its prerequisites are mastered. The graph must have no cycles (a test enforces it). **Changing or removing a prerequisite, or removing a skill, needs Spiro's sign-off** and an entry in `docs/decisions.md`. To propose one, write: the skill id, the old and new prerequisites, and why. Entries marked "Needs reviewer" in `docs/decisions.md` list what has not been checked yet.

## 3. Looking at real problems

`docs/reviews/math-review-packet-zN.md` (Zones 6 to 11 and the Phase 2 packet) lists sample problems per skill as a child sees them: the question, the right answer, the wrong answers and the hint steps. To make fresh ones, ask a developer to run (needs the Godot editor binary):

```bash
"$GODOT" --headless --path . res://tools/qa/math_review_packet.tscn -- --zones 12 --samples 30
```

To check the answers by machine: `python tools/crosscheck/run.py --skill <skill id> --n 20 --seed 3` re-derives every answer and wrong answer in a separate Python program (it shares no code with the generators). It prints the skill and seed of any failure so the problem can be reproduced.

## 4. What to check in a problem

- Is the question's wording clear for a strong first-grade reader (short, one instruction)? Numbers appear as `{n}`-style placeholders in `text/lines.csv`.
- Is the answer correct, and is it the only correct answer (or are equal forms accepted)? Fractions and decimals count by value, except skills marked simplest-form.
- Is each wrong answer a mistake a child really makes, and does its misconception name say so? A wrong answer never equals the right one and is never repeated.
- Does each representation show the same mathematics? Do the hint rungs (a nudge, a model, a worked example, an easier problem) lead to the answer?
- Are the prerequisites sound: is anything needed missing, or required that is not?

## 5. Vocabulary and Word Gems

`curriculum/vocabulary.json` maps each math term to a kid-sized definition (the words live in `text/lines.csv`, lines `vocab.<term>.term` and `vocab.<term>.definition`). Real math terms are always used, with the kid explanation the first time. Please check each definition is true, simple and complete enough.

## 6. Proof files (Zone 12)

Guided proofs are data in `curriculum/proofs/*.json`: a list of steps (each a statement line, a justification and the steps it depends on), decoy tiles that look right but carry a named flaw, and a flag for whether the order is strict or any valid order. Check that every step truly follows from the ones it depends on, that each decoy is really flawed, and that the wording stays honest for a young reader.

## 7. How mastery is decided

Each skill keeps a probability that the child knows it, updated after every answer (Bayesian Knowledge Tracing: a starting guess, a learning rate, a guess rate and a slip rate; defaults in `curriculum/bkt_defaults.json`). A skill counts as mastered when that probability is at least 0.95 **and** the child answered correctly on at least two different days; math-fact skills also need steady speed (never shown to the child). A hint-assisted answer counts as partial evidence; a wrong answer costs nothing the child can see. Only skills whose prerequisites are mastered are offered, about 70% new practice and 30% review at 1, 3, 7, 21 and 60 days. Simulated learners in the tests show a random guesser never masters anything. **These thresholds are not to be changed casually**; propose changes to Spiro with data.
