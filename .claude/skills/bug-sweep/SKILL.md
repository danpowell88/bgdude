---
name: bug-sweep
description: When fixing a bug in bgdude, sweep the whole surface instead of patching only the reported site. Use for any bug fix, and when reviewing someone else's fix. The most common defect is a fix that guards its literal target but leaves the symmetric or adjacent path unguarded — check the four axes here before calling a fix done.
---

# Fixing a bug? Sweep the whole surface — don't just patch the reported site

The single most common defect the review pass finds is a fix that **protects its literal
target but leaves the symmetric/adjacent path unguarded**. This recurs (e.g. `@Volatile`
fixed visibility but not the compound-op race → a follow-up was needed; a persist gate was
applied to the annotation but not the sibling notification; a clamp guarded three divisions
and missed the fourth; per-field range validation shipped without the ordering invariant; a
"crash detector" test couldn't actually fail). Before you call a fix done, sweep these four
axes:

- **Sibling call sites** — `grep` for the *same construct* you just fixed and patch every
  occurrence, not only the one in the ticket. If you guarded one `/ isf`, one `.values[i]`
  enum decode, one `jsonDecode`, one unclamped field — find the others in that file and its
  siblings and guard them too (or state why they don't need it).
- **Both branches / every side-effect of the same action** — if you gate something on
  success, gate *every* user-visible effect of that action the same way (persist-before-emit
  applies to the annotation **and** the notification **and** the state). Handle the failure
  branch, not just the happy path. If you validate a value, validate its relationships too (a
  per-field range check is not an ordering check).
- **A test that actually fails if the fix is reverted** — every fix ships with a negative-case
  test whose assertion is on the *real invariant/output*, not `returnsNormally` / "no throw" /
  a log the test binding never populates. If you can't make it fail by reverting the fix, the
  test is hollow. Prove it: revert, watch it go red, restore.
- **Concurrency & security nuance** — visibility ≠ atomicity (`@Volatile` doesn't make a
  read-modify-write atomic); a host-allowlist check is not a scheme check; a redirect re-checks
  per hop. When the fix touches threads, tokens, or redirects, reason about the *other* way it
  can still go wrong.

## Reviewing someone else's fix?
Apply the same four axes before trusting the green checkbox — "the fix compiles and its one
test passes" is exactly the state these misses hide in.
