# Closed test plan (Sprints 25-27)

The closed test gives real families the game before the public launch. On a **personal** developer account it is also required: **12 or more opted-in testers for 14 consecutive days** before production access can be requested (Phase 3 plan, 3.10). An organization account is exempt, but the test still runs for the feedback. **Spiro: confirm the current rule in Play Console's help before recruiting** (it has changed before).

## Who and how long

| | |
|---|---|
| Testers | **12 or more** families (aim for 15 so a drop-out does not break the count), from school and friends; children 6-12 on Android tablets or Chromebooks. Keep a reserve list |
| Length | **14 consecutive days**, without removing testers or pausing the track. A mid-test build (Sprint 27) does not break the 14 days |
| Earliest end | Start date + 14 days. On a personal account the test must start by May 11, 2027 to end by May 25 (Phase 3 plan, "Decisions for Spiro" 5) |
| Track | Play Console closed testing, with an email list or a Google Group of the testers' Google accounts |
| Builds | rc1 (Sprint 26), rc2 mid-test (Sprint 27), both through `docs/release-checklist.md` |

Record: start date ____, testers opted in on day 1 ____, end date ____.

## Recruiting (Sprint 25, P3-S25-07)

- [ ] List of families with the Google account each will test with and the device (tablet or Chromebook; no phones: the app excludes them).
- [ ] Each family agrees to: install from the Play link, play at least three sessions over the two weeks, and fill in the feedback form once a week.
- [ ] Mention that the app collects nothing and works offline (the privacy policy link), so nothing is learned about their child unless they write it in the form.

## The tester email (sent with the invitation, P3-S26-04)

One page, plain language. It contains:

1. The opt-in link and the Play Store link, with install steps for a tablet and for a Chromebook.
2. What to try: first-time setup by a parent who has never seen the game (the parent area, adding a child profile), a few sessions by the child alone, and moving progress to a second device if they have one.
3. **How to send feedback: a short form link** (a Google Form or similar run by Spiro). The game itself has no network and no feedback button; the form lives only in the email. The parent area's "Copy diagnostics" button (Phase 3, P3-S26-05) copies the app version, the device model and a few non-personal log lines for pasting into the form.
4. A reminder that the app sends nothing anywhere, and that they should not put a child's full name or photo in the form.

Form questions (keep it under 5 minutes): device and posture; child's age; what was confusing in setup; where the child got stuck; any crash or freeze (what screen, what they did); what the child liked; anything else. One free-text box for "Copy diagnostics".

## Triage (Sprint 27, P3-S27-01)

Collect every form response and every Play Console report (crashes, ANRs, pre-launch report, testers' private feedback) twice a week into the GitHub Projects board, one card per issue:

| Label | Means | Action |
|---|---|---|
| `launch-blocker` | A crash, a freeze, lost progress, a setup step a parent could not finish, anything against `CLAUDE.md`'s non-negotiable rules or content rules | Fix first, in the mid-test build |
| `fix-before-launch` | A screen a child could not finish, confusing wording, a layout broken on a tester's device | Fix in Sprint 27 or 28 as time allows |
| `backlog` | Ideas and wishes | Into the backlog for Phase 4; do not build ahead |
| `wont-fix` | Against the design (timers, random rewards, ...) | Reply kindly, close |

- Reproduce each crash on the emulator matrix or a real device before fixing; note the device model.
- A fix that needs a save schema change still needs a migration, a fixture and Spiro's sign-off, even mid-test.
- Text changes touch `text/lines.csv` only, with new line IDs where the meaning changes (`CLAUDE.md`, line IDs).
- The mid-test build goes out through `docs/release-checklist.md` to the closed track; check the testers receive it and the 14 days continue.

## Exit (before production access)

- [ ] 14 consecutive days completed with 12 or more opted-in testers (personal account), or the organization route chosen.
- [ ] No open `launch-blocker` card.
- [ ] A short summary of what tester families taught us, for the Phase 3 retro note in `docs/decisions.md` (P3-S28-05).
