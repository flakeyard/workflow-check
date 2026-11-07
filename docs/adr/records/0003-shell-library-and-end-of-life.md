---
id: ADR-0003
title: Shell library and the end of life of nixpkgs
status: accepted
date: 2026-11-07
supersedes: []
superseded_by: []
related: [ADR-0001, ADR-0002]
affects:
  [
    ".github/workflows/check.yaml",
    ".github/workflows/maintenance.yaml",
    ".github/actions/**",
    "tests/**",
    "nixpkgs-eol",
  ]
review_by:
---

## Context

Two decisions of flakeyard change what this workflow runs.

[FY-0036][fy-0036] supersedes [FY-0026][fy-0026] in its end-of-life part.
action-flake-lock derives the end of life from the branch of each root nixpkgs
input of `flake.lock` and has a new input `nixpkgs-eol`, `true` by default
([action-flake-lock ADR-0002][afl-0002]). From 30 days before the end of life it
warns; after it, it fails only in runs of the `schedule` event and warns in
every other one. The `nixpkgs-eol` file and the weekly end-of-life job of every
repository are removed once every repository runs a release of workflow-check
with the rule. A repository with a flake MUST have a weekly `schedule` that runs
workflow-check, or that runs action-flake-lock itself.

[FY-0035][fy-0035] requires that logic with two users lives in one place, also
across repositories. Shell code that actions run without Nix is delivered by the
library action [action-shell-lib][asl-0001]: a step of it writes its own
directory to the output `path`, and the consumer passes that path as `SHELL_LIB`
and sources files from it. Its step needs `/usr/bin/bash`, so it runs on Linux
only. FY-0035 lets the logic of an action live in a pinned library action and
lets tests take the library's source, test helpers in `internal/testing/`
included, at the pinned commit. A major release of the library is not by itself
a major release of a consumer.

This repository keeps such code in `.github/actions/lib`: `report.sh` and, under
`github/`, `api.sh`, `contents.sh`, `jobs.sh` and `repository.sh`, next to
`flake.sh` and `renovate.sh`. workflow-release, action-flake-lock,
action-setup-nix and other repositories carry copies that have diverged. Each
internal action finds the library relative to its own `run.sh`.

Besides the check workflow of
[ADR-0001](0001-check-pull-requests-and-pushes.md), two kinds of workflow post
commit statuses of dispatched runs: `check.yaml`, and the `maintenance.yaml` of
several repositories, which runs the end-of-life job and, in image-devcontainer,
a weekly rebuild of the image. With the end-of-life job gone, the rebuild is the
only reason left for a second workflow.

## Decision

### End of life of nixpkgs

A new boolean input `nixpkgs-eol`, `true` by default, is passed to
action-flake-lock in the job `flake`. When it is `false`, the job `meta` emits a
notice that the end-of-life check is switched off, as it does for `flake-lock`
(ADR-0002). When `flake-lock` is `false` or `flake` is `""`, the action does not
run, and the existing notice of ADR-0002 covers the end of life as well.

The event of a called workflow is the event of its caller, so the weekly
`schedule` of the caller's `test.yaml` is the run in which the end of life
fails. This repository's own `maintenance.yaml` and `nixpkgs-eol` are removed
when FY-0036 says.

The check can fail a scheduled run of a passing project. workflow-check is in
its `0.y.z` previews ([FY-0024][fy-0024]), so it adopts the release of
action-flake-lock with the rule, and the input, in a `0.y` bump, with
`nixpkgs-eol` on by default, as ADR-0002 did for `flake-lock`.

### Shell library

workflow-check adopts action-shell-lib. Each job of `check.yaml` calls the
library once, as its first step after the checkout if it has one, with an `id`,
and passes the output `path` to its internal actions as an input, which their
`action.yml` gives to `run.sh` as the variable `SHELL_LIB`. Internal actions do
not call the library themselves, so the `uses:` pin of the library appears once
per job, all at the same commit, and not in every internal `action.yml`.

A module of `.github/actions/lib` moves to the library when another repository
uses it too; the copies of `report.sh`, `api.sh` and `contents.sh`, and the
forms of repositories and flakes, are such modules. A module that only
workflow-check uses stays here. The stubs and the harness of the tests move to
the library's `internal/testing/` on the same terms; tests take the library's
source at the commit pinned in `check.yaml`.

workflow-check pins action-setup-nix and action-flake-lock, which pin the
library themselves. A change of the library is released first in the library,
then in action-setup-nix and action-flake-lock, then in workflow-check once, so
that one release of workflow-check adopts all three.

Adopting the library changes no input, output, permission, event or runner of
workflow-check. A major release of the library is a major release of
workflow-check only when it changes that public API.

### Scheduled jobs of callers

A job that a caller runs only on a schedule, such as the weekly rebuild of the
image of image-devcontainer, is a job of its `test.yaml`:

```yaml
jobs:
  rebuild:
    # No name: caller-may-skip matches the job id.
    if: ${{ github.event_name == 'schedule' }}
    runs-on: ubuntu-24.04
    steps: [...]

  check:
    needs: [rebuild]
    uses: flakeyard/workflow-check/.github/workflows/check.yaml@<commit> # vX.Y.Z
    with:
      needs: ${{ toJSON(needs) }}
      caller-may-skip: '["rebuild"]'
```

The job is listed in `needs` of `check` and in `caller-may-skip`, so that the
runs of other events, where it is skipped, still pass, and a scheduled run fails
when it fails. With the end-of-life job in action-flake-lock and such jobs in
`test.yaml`, `maintenance.yaml` disappears from every repository, and only
`check.yaml` posts commit statuses of dispatched runs.

This is the documented pattern for scheduled jobs of callers. It uses the caller
contract of ADR-0001 as it is and changes none of its rules.

### Changes to ADR-0001 and ADR-0002

This record amends [ADR-0001](0001-check-pull-requests-and-pushes.md) and
[ADR-0002](0002-check-flake-lock.md); their other decisions and constraints
stand:

- "Public API" (ADR-0001, extended by ADR-0002): the inputs are `needs`,
  `caller-may-skip`, `flake`, `systems`, `expect-checks`, `extra-substituters`,
  `extra-trusted-public-keys`, `timeout-minutes`, `pr-title`, `pr-title-types`,
  `renovate-config`, `renovate-presets`, `release-tags`, `allow-unpinned`,
  `flake-lock`, `allow-duplicates` and `nixpkgs-eol`. The booleans `pr-title`,
  `renovate-config`, `release-tags`, `flake-lock` and `nixpkgs-eol` switch
  single checks and are `true` by default.
- "Caller contract" (ADR-0001): a job that runs only on a schedule follows the
  pattern above.
- "Product" (ADR-0001): the scripts that run in the steps may come from the
  pinned library action, besides `.github/actions`.

## Constraints

- The job `flake` MUST pass the input `nixpkgs-eol`, a boolean, `true` by
  default, to action-flake-lock.
- When `nixpkgs-eol` is `false`, the job `meta` MUST emit a notice saying that
  the end-of-life check is switched off; it MUST NOT be left out silently.
- Each job of `check.yaml` that runs library code MUST call action-shell-lib
  exactly once, as its first step after the checkout if it has one, and MUST
  pass its output `path` to the internal actions that need it.
- Internal actions MUST NOT call action-shell-lib themselves. Every `uses:` of
  action-shell-lib in `check.yaml` MUST name the same commit, by full SHA.
- Logic that another repository also uses MUST come from action-shell-lib, not
  from a copy in `.github/actions/lib`.
- Tests MUST take action-shell-lib at the commit pinned in `check.yaml`.
- Adopting a release of action-shell-lib MUST NOT change the public API of
  workflow-check; it MAY be released as a major version only when it does.
- A caller's job that runs only on a schedule MUST be a job of its `test.yaml`,
  with `if: ${{ github.event_name == 'schedule' }}`, listed in `needs` of
  `check` and in `caller-may-skip`.

## Consequences

- (+) No repository keeps a `nixpkgs-eol` file, an end-of-life job or a
  `maintenance.yaml`; the weekly run of `test.yaml` checks the date.
- (+) The report, API and contents logic exists once, in the library, and fixes
  reach every repository through one release chain.
- (+) Only `check.yaml` posts commit statuses of dispatched runs, so the status
  protocol has one implementation.
- (−) A change of the library reaches workflow-check only after releases of the
  library, action-setup-nix and action-flake-lock.
- (−) The library is fetched once per job, which adds a step to every job.
- (−) A job that runs only on a schedule now delays `check / required` of
  scheduled runs, and its failure fails it.
- (±) A caller that turns off `flake-lock` turns off the end-of-life check too,
  and is told so by the notice.

## Alternatives considered

- **Each internal action calls the library.** Simpler wiring, but the pin is
  repeated in every `action.yml`, and one job runs the library step many times.
- **Keep `maintenance.yaml` for scheduled jobs.** Leaves a second workflow that
  posts commit statuses, so the status protocol stays copied in every
  repository.
- **Vendored copies of the library generated into this repository.** No extra
  step, but the code is still duplicated, and Renovate cannot update a vendored
  copy.
- **Do not expose `nixpkgs-eol`.** One input less, but a caller could not switch
  the new rule off without switching off the whole check of `flake.lock`.

[afl-0002]:
  https://github.com/flakeyard/action-flake-lock/blob/main/docs/adr/records/0002-end-of-life-of-nixpkgs.md
[asl-0001]:
  https://github.com/flakeyard/action-shell-lib/blob/main/docs/adr/records/0001-shell-library.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0026]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0026-stable-nixpkgs.md
[fy-0035]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0035-extract-logic-that-has-two-users.md
[fy-0036]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0036-check-the-end-of-life-of-nixpkgs-in-flake-lock.md
