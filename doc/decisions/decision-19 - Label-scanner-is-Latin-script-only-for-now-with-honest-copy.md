# Decision 19 — the label scanner is Latin-script only (for now), and says so

- **Date:** 2026-07-19
- **Status:** proposed — the "for now" is Summer's to confirm or overturn (issue #103 AC#4
  asks for the decision to be informed by real usage, which has not happened yet)
- **Context:** issue #103

## Decision

bgdude's nutrition-label scanner reads **Latin-script labels only**. ML Kit's Chinese,
Japanese/Korean, Devanagari and Cyrillic recognizers are **not** wired in.

What changes today is honesty, not scope: when the scan fails and the OCR text is
dominated by a script the recognizer cannot read, the app **names that script and says
retaking the photo will not help**.

## Why not just add the recognizers

Not because it is hard — it is a recognizer per script plus detection. Because:

- Each additional ML Kit script model **increases the APK**, and this is a personal app
  for one person in Australia whose labels are Latin-script.
- The scanner already has an AI fallback for unusual layouts. Feeding it CJK garbage does
  not produce a bad answer to be improved — it produces a **confidently wrong** one, which
  is worse than a refusal in an app that sits next to insulin dosing.
- The issue itself asks for the decision to be **informed by real usage**. There is no
  real usage yet. Adding four recognizers speculatively is the more expensive way to be
  wrong.

## Why the detector is worth adding regardless of that decision

This is the part that does not depend on the scope call, and is why it was implemented
rather than deferred with the rest.

The Latin recognizer does not *fail* on a Japanese label. It returns confident nonsense,
which flows into the parser and, if a model is installed, the LLM. The user then sees
*"couldn't read the panel — try a straight, well-lit photo"* and reasonably concludes the
photo was the problem, and takes it again. And again. The app is effectively lying about
why it failed.

Naming the script is strictly better under **either** outcome:

- If CJK support is never added, this is the honest copy AC#2 asks for.
- If it is added later, the detector simply stops firing for those scripts — nothing to
  unwind.

The threshold is 30% of letter-ish characters, not zero, because a Latin panel legitimately
carries the odd non-Latin mark (a brand name, a ™, a °). Firing on those would tell people
their English label is unsupported, which is a worse failure than the silence it replaces.

## Consequences

- `doc/user-guide.html` states the Latin-only limitation.
- Adding a script later means wiring its ML Kit recognizer and removing it from
  `UnsupportedScript` — the detector is the list of what is *not* supported, so it stays
  accurate by construction.
- **Unresolved:** whether to support any additional script at all. That needs Summer, and
  ideally a real label that failed.
