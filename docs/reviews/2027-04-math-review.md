# Math review of Zones 1 to 5 (Sprint 21, P2-S21-02)

**Status: AI pre-review done; the human math reviewer's session and sign-off are still needed.** The reviewer works from `docs/reviews/math-review-packet-z1-5.md` (regenerate it with `tools/qa/math_review_packet.tscn` first) and records the findings and sign-off below. All blocking notes must be fixed before the `v1.0.0` tag.

## 1. AI pre-review (2026-10-17)

An independent AI pass read the 72-skill packet, the skill files and the generators. It also recomputed the sieve answer lists in Python.

**Result: no blocking math errors.** Every stated answer is correct. No listed wrong answer is also right. Prerequisites only point backward. The findings below are about wording, feedback and teaching.

### Fixed in this pass

The feedback lines below were rewritten (text only). They take effect before Phase 3, so no narration exists to regenerate.

| Where | Finding | Fix |
|---|---|---|
| `z5.fta.theorem`, `vocab.fundamental_theorem.definition` | "Every number has exactly one prime recipe" is false for 0 and 1. It also leaves out that order does not matter. | "Every number bigger than 1 has just one prime recipe. Order does not matter." |
| `bolt.misconception.decade_skip` | "One ten too far?" was also shown when the child was one ten short. | "Check the tens. One ten too many or too few?" |
| `bolt.misconception.forgot_untrade` | The line did not describe the actual mistake (62 − 8 → 64: the ten was broken but not taken from the tens). | "You broke a ten. Take it away from the tens too." |
| `bolt.misconception.missing_one_and_n` | "Do not forget one" made no sense for "Is 29 a factor of 29?". | "Remember: 1 and the number itself are factors too." |
| `div.facts.*` | ÷ was introduced with no Word Gem for *divide*. | New Word Gem "divide" on the two division-fact skills. Lint rule 11 now also catches divide, division and ÷. |

### Open: needs a decision or a code change (SHOULD)

Ask Spiro or the reviewer about each of these.

- **Prerequisites (need Spiro's sign-off):**
  - Add `pv.tens_ones.read` to `count.write.numeral`. Its abstract form says "5 tens and 1 ones".
  - Add `parity.even_odd.rule` to `div.rule.2_5_10`. The rule for 2 is the even/odd rule.
- **"1 ones", "1 tens":** the place-value prompts need singular and plural forms. This needs plural-aware lines, for example separate line ids for 1.
- **Shared feedback lines whose fix needs a misconception split.** Each item below needs a new misconception name, plus generator and checker changes:
  - `forgot_regroup` is shown backwards on `pv.regroup.untrade`.
  - `counted_from_one` (6 + 1 → 6) is really "counted the start twice".
  - `rows_plus_cols` is used on equal groups, which have no rows.
  - `no_check_made` is used on prime recipes.
  - The parity rule skill's feedback talks about pairs instead of the last digit.
- **Unify the meaning of a × b.** Is it a groups of b, or b groups of a? `off_by_group` uses the other meaning from the arrays.
- **`prime.classify.single`:** the prompt says "unbreakable" but never "prime" or "composite". Consider switching to "Is 13 a prime?" after the term is introduced.
- **`div.sharing.equal_shares` feedback:** "The answer gets smaller" is not true in general.
- **`div.rule.*`:** numbers go up to 231, but place value is only taught up to 120.

### Nits (optional)

- Repeated sample problems for some seeds: `pv.tens.ten_more_less`, `pv.hundred.intro`, `div.sharing.equal_shares`. Check the variety.
- `count.to_120.next` offers 122 as a wrong answer, which is above the skill's range.
- Misconception label `picked_smaller` on a "fewer" question; `digit_swap` labelled `added_tens_to_ones`; `[19, 23]` labelled `wrong_step`.
- `div.facts.by_6_10`: "multiplied instead" answers such as 490 are implausible taps.
- Sieve wording: "not a prime" should be "not prime". "A prime needs two." should be "A prime has exactly two factors."

## 2. Human reviewer session (to fill in)

- Reviewer:
- Date:
- Zones covered:
- Blocking notes (each with its fix and commit):
- Other notes:
- **Sign-off:** Zones 1-5 approved for Version 1.0: yes / no
