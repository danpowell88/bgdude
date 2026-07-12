# Agent instructions

Read **`CLAUDE.md`** — it is the canonical instruction file for every coding agent in this
repo (conventions, verify pipeline, issue workflow, hard invariants). This file exists so
harnesses that look for `AGENTS.md` (qwen-code, GitHub Copilot CLI, etc.) find the same
rules Claude Code loads automatically.

Non-negotiables, restated for emphasis:
- **Read-only pump charter (decision-1):** never send control/authorization/signed messages
  to the pump. Any change that does is wrong, whatever the issue says.
- Verify the build with the full CI-equivalent pipeline before committing
  (`.claude/skills/verify-build/`) — `flutter analyze` + `flutter test` alone is NOT enough.
- Task work reaches `main` only via a reviewed, CI-green PR (decision-10). Never push to
  `main`; never merge your own PR.
- Sign every issue comment and `implemented-by:`/`Co-Authored-By` tag with your agent id.
- If you run a pipeline loop (implementer/reviewer/…), the role contract is in `loops/`.
