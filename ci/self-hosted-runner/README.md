# Self-hosted CI runner for bgdude (Unraid)

A Docker container that registers as a GitHub Actions self-hosted runner with Flutter + Android
baked in, so CI can build **feature branches** (unblocking the decision-8 review-merge gate,
TASK-309) without burning GitHub-hosted minutes — and, in phase 2, run the Android **emulator**
suite reliably via `/dev/kvm` (unblocking the on-device ACs and the failing nightly, TASK-219).

## ⚠️ Security — read first (this repo is PUBLIC)
GitHub advises against self-hosted runners on public repos: a malicious **fork pull request** can
run arbitrary code on the runner — i.e. on your Unraid box / home LAN. You have 0 forks today, so
exposure is currently ~nil, but keep these guardrails:
- **`EPHEMERAL=true`** (set in compose) — a fresh runner per job; nothing persists between jobs.
- **Never let fork PRs run on it.** The workflow guard (below) restricts the self-hosted jobs to
  same-repo refs. GitHub's default "require approval for fork PRs" should also stay on
  (repo → Settings → Actions → General → Fork pull request workflows).
- **No `--privileged`.** Phase 2 needs only `--device /dev/kvm`.
- Run it on an isolated Docker network / VLAN if you can, and don't hand it secrets it doesn't need.

## Prerequisites (on the Unraid host)
- CPU virtualization (VT-x / AMD-V) enabled in BIOS — needed for the phase-2 emulator.
- `/dev/kvm` present: `ls -l /dev/kvm` (phase 2 only).
- The Docker or Compose Manager plugin.

## Setup (phase 1 — branch builds: analyze / test / build apk)
1. **Get a token:** create a fine-grained PAT scoped to `danpowell88/bgdude` with
   *Administration: Read and write* (see `.env.example`). `cp .env.example .env` and paste it in.
2. **Build + start:**
   ```sh
   cd ci/self-hosted-runner
   docker compose --env-file .env up -d --build
   ```
   (First build downloads the Android SDK + Flutter — several GB, a few minutes.)
3. **Verify:** repo → Settings → Actions → Runners should show **`unraid-bgdude` — Idle** with the
   `unraid` label. `docker logs bgdude-ci-runner` shows the registration.

### Unraid "Add Container" UI mapping (if you don't use Compose Manager)
Build the image once on a shell (`docker build -t bgdude-ci-runner ci/self-hosted-runner`), then:
- **Repository:** `bgdude-ci-runner:latest`
- **Extra Parameters:** `--restart unless-stopped` (phase 2: add `--device /dev/kvm`)
- **Variables** (Add another Path/Port/Variable → Variable): `REPO_URL`, `RUNNER_SCOPE=repo`,
  `ACCESS_TOKEN=<your PAT>`, `RUNNER_NAME=unraid-bgdude`, `LABELS=self-hosted,linux,x64,unraid`,
  `EPHEMERAL=true`, `DISABLE_AUTO_UPDATE=true`
- **Paths:** container `/actions-runner/_work` → a share (e.g. `/mnt/user/appdata/bgdude-runner/_work`)

## Wiring CI to the runner (`.github/workflows/ci.yml`)
Two changes — do these once the runner shows Idle (I can prepare them on request):
1. **Build branches**, not just `main`:
   ```yaml
   on:
     push:
       branches: [main, 'task-**']    # + keep the backlog/doc/md paths-ignore
     pull_request:
       branches: [main]
   ```
2. **Route jobs to the runner** and **block fork PRs** on it:
   ```yaml
   jobs:
     test:
       runs-on: [self-hosted, unraid]                 # or keep fast jobs on ubuntu-latest
       if: github.event_name == 'push' || github.event.pull_request.head.repo.full_name == github.repository
   ```
   You can mix: keep `analyze`/unit `test` on `ubuntu-latest` and route only `build apk` +
   the emulator job to `[self-hosted, unraid]`. Whatever runs on self-hosted MUST carry the
   fork-PR `if:` guard.

## Phase 2 — the Android emulator (optional, unblocks TASK-219 + on-device ACs)
1. Rebuild with `WITH_EMULATOR=true` (compose build arg) — installs the `android-34` `x86_64`
   system image + creates the `bgdude_api34` AVD.
2. Uncomment the `devices: - /dev/kvm` line in `docker-compose.yml` and restart.
3. Route the emulator job to `[self-hosted, unraid]`. The existing nightly uses
   `reactivecircus/android-emulator-runner`; on a self-hosted runner with KVM it should boot the
   AVD reliably (that's the fix for the flaky GitHub-hosted nightly).

## Fresh-per-build (ephemeral) on Unraid
"Fresh each build" has two layers — decide how far you want to go:

- **Runner-ephemeral (easy, native to the compose above).** `EPHEMERAL=true` makes the runner
  take exactly **one job then exit**; `restart: unless-stopped` brings the container back and it
  re-registers for the next job. Combined with `actions/checkout` (which wipes the workspace at
  the start of every job), each build gets a **clean workspace**. The container's writable layer
  technically survives the restart, so this is "fresh workspace" not "fresh filesystem" — good
  enough for almost all CI, and it needs nothing beyond the compose file.

- **Truly fresh filesystem per build (a brand-new container each job).** Recycle the container
  with `--rm` so its writable layer is discarded per job. Unraid's Docker **UI** can't do this
  (its restart policy reuses the same container), so drive it from the **User Scripts** plugin
  (or a host systemd unit) as a respawn loop:
  ```sh
  # Unraid User Scripts: schedule "At startup of array" + keep running.
  while true; do
    docker run --rm --name bgdude-runner \
      --env-file /mnt/user/appdata/bgdude-runner/.env \
      -e REPO_URL=https://github.com/danpowell88/bgdude -e RUNNER_SCOPE=repo \
      -e RUNNER_NAME=unraid-bgdude -e LABELS=self-hosted,linux,x64,unraid \
      -e EPHEMERAL=true -e DISABLE_AUTO_UPDATE=true \
      -e ACCESS_TOKEN="$GH_RUNNER_PAT" \
      # phase 2 only: --device /dev/kvm \
      bgdude-ci-runner:latest
  done   # EPHEMERAL runner exits after 1 job -> --rm discards the container -> loop starts a fresh one
  ```
  This is the recommended shape for a **public** repo: a compromised job can't leave anything for
  the next build, because there IS no next build in that container.

Either way the **baked SDKs stay fast** — Flutter/Android live in the read-only image layers, so a
fresh container still has them; only the writable workspace is new. Caches are the one trade-off:
mount `gradle-cache`/`pub-cache` volumes for warm-but-shared caches, or drop the mounts for
fully-cold-but-pristine builds. For a public repo, prefer no shared cache (or a read-only mount).

## Keeping it in sync
Versions here (Flutter 3.44.4, JDK 17, compileSdk 36 / targetSdk 37, emulator API 34) mirror
`ci.yml` + `android/app/build.gradle`. If those bump, bump the Dockerfile ARGs and rebuild.

Untested template — expect to tweak versions, the runner uid/permissions, and the KVM passthrough
for your host. Log friction you hit as `friction:tooling` on the runner task so the meta loop sees it.
