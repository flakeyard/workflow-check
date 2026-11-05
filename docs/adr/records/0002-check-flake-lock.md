---
id: ADR-0002
title: Check flake.lock with action-flake-lock
status: accepted
date: 2026-11-05
supersedes: []
superseded_by: []
related: [ADR-0001]
affects: [".github/workflows/check.yaml"]
review_by:
---

## Context

[FY-0016][fy-0016] requires that the `rev` of every flakeyard input of a
`flake.lock` is the commit of a release `vX.Y.Z` of the major version its `ref`
names, and that inputs use one pin form. [FY-0017][fy-0017] requires that a lock
has no duplicate inputs and that CI generated from a template runs
`action-flake-lock` before any Nix evaluation.
[ADR-0001](0001-check-pull-requests-and-pushes.md) left this check to a later
minor version, and [FY-0022][fy-0022] makes `action-flake-lock` the next step
after workflow-check and workflow-scorecard.

The design of the action is recorded in its own repository, in
[action-flake-lock ADR-0001][afl-0001]. What workflow-check has to know of it:

- It checks one lock file, by default `flake.lock`, with three rules: the
  release rule of FY-0016 for flakeyard inputs, duplicate inputs (FY-0017) and
  the pin form of FY-0016 for root inputs. The first two are always on; the pin
  form is switched by the input `pin-form`, `true` by default.
- Inputs: `path`, `allow-duplicates` (a newline list of normalized sources, such
  as `github.com/nixos/nixpkgs` or `github.com/o/r?dir=sub`), `pin-form` and
  `github-token` (by default `github.token`, which needs no permissions). No
  outputs. A tightening of a rule is a major release of the action.
- It takes `jq` and `gh` from its own flake, pinned by its own lock, and
  evaluates only that flake, never the one of the repository it checks. It does
  not install Nix: Nix with `nix-command` and `flakes` must be on `PATH`, with
  the runner's `git` and `bash`. It supports GitHub-hosted Linux runners, x86_64
  and arm64.
- It reports every violation of a run in the job summary and as annotations, and
  fails; it has no mode that only warns. A release it could not verify is
  reported apart from a violation and also fails the run.

The flake jobs of workflow-check already check out the repository and install
Nix with action-setup-nix, which evaluates nothing; the next step,
`flake-checks`, is the first that evaluates the repository's flake. The checks
of the `meta` job read files through the contents API and do not check out code
(ADR-0001, "Checks").

FY-0024 lets a minor release add a check that could fail a passing project only
while the product is in its `0.y.z` previews; from `v1.0.0` on, such a check
ships disabled and is enabled in the next major version.

## Decision

The check of `flake.lock` is a step of the job `flake` of every system: the
first step after action-setup-nix and before `flake-checks`. It runs
`action-flake-lock`, pinned by full commit SHA, on `<flake>/flake.lock`. "Before
any Nix evaluation" of FY-0017 means before the repository's flake is evaluated;
the action evaluating its own flake does not count. `flake-checks` still runs
when the check fails (`if: ${{ !cancelled() }}`), so one run reports both. Since
the check runs in the job of every system, its annotations repeat once per
system; that is accepted.

The check reads the lock of the checkout in the job that builds the flake, not
through the contents API, so that it checks the very lock Nix uses, and it runs
with the tools of the action, not with the runner's `gh` and `jq`. This is an
exception to the "Checks" constraint of ADR-0001 for this check only.

workflow-check passes no token: the action uses `github.token`, and the job
`flake` keeps only `contents: read`. The pin form stays on for every caller, as
FY-0016 binds every flakeyard repository and generated project; workflow-check
does not expose `pin-form`.

### Public API

This decision adds two inputs to the list of ADR-0001:

- `flake-lock` (boolean, default `true`): switches the check.
- `allow-duplicates` (default `[]`): JSON array of normalized sources that may
  appear more than once, like `allow-unpinned`; workflow-check passes it to the
  action as a newline list. A second nixpkgs for a broken tool
  ([FY-0026][fy-0026]) goes there.

The permissions, events, runners, secrets and outputs of ADR-0001 do not change.
`flake-lock` is `true` by default although the check can fail a passing project:
workflow-check is still in its `0.y.z` previews, and the check ships in a minor
release.

When `flake-lock` is `false`, or `flake` is `""` so that there are no flake
jobs, the job `meta` emits a notice that the check is switched off or does not
apply. This is how the check, which has no job of its own, meets the rule of
ADR-0001 that a switched-off or non-applicable check succeeds with a notice.

workflow-check adopts the action in its first pull request after the first
release of `action-flake-lock`, as FY-0022 requires.

## Constraints

- The job `flake` MUST run `action-flake-lock`, pinned by full commit SHA, on
  `<flake>/flake.lock` as its first step after action-setup-nix, before any step
  that evaluates the repository's flake.
- `flake-checks` MUST run also when the check of `flake.lock` failed, unless the
  run was cancelled.
- The check MUST be switched by the input `flake-lock`, `true` by default, and
  intentional duplicates MUST be given by the input `allow-duplicates`, a JSON
  array, `[]` by default. workflow-check MUST NOT switch off the pin form.
- When `flake-lock` is `false` or `flake` is `""`, the job `meta` MUST emit a
  notice saying so; the check MUST NOT be left out silently.
- The check MUST NOT add permissions to the job `flake` beyond `contents: read`
  and MUST NOT pass a secret to the action.
- Only this check MAY read a repository file from the checkout of the job that
  builds the flake and run tools other than the runner's `bash`, `gh` and `jq`;
  every other check stays bound by the "Checks" constraint of ADR-0001.
- From `v1.0.0` on, adopting a major release of `action-flake-lock` MUST be
  released as a major version of workflow-check.

## Consequences

- (+) Every caller gets the release rule, duplicates and the pin form checked in
  CI, before its flake is evaluated, with no change to its workflow.
- (+) The check reads the same lock that Nix then uses, and needs no Nix install
  and no job of its own.
- (−) A caller whose lock breaks a rule fails after the minor release that
  adopts the check, unless it sets `flake-lock: false` or lists the duplicate.
- (−) The check runs once per system, so its annotations and its API lookups
  repeat on every flake job.
- (±) The "Checks" constraint of ADR-0001 has one exception, stated here.

## Alternatives considered

- **A separate job `flake-lock` before the matrix.** Runs once, but installs Nix
  a second time and adds 30 to 40 seconds before the flake jobs start.
- **Reading the lock through the contents API in `meta`.** Keeps the "Checks"
  constraint whole, but the action would need its own Nix there, and the lock it
  reads could differ from the checkout the flake jobs build.
- **`flake-lock` disabled by default.** What FY-0024 asks after `v1.0.0`; in a
  preview it would leave the rules of FY-0016 and FY-0017 unchecked by default.
- **Exposing `pin-form`.** Lets a caller turn off a rule that FY-0016 makes
  binding for every repository.

[afl-0001]:
  https://github.com/flakeyard/action-flake-lock/blob/main/docs/adr/records/0001-check-flake-lock.md
[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0022]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0022-bootstrap.md
[fy-0026]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0026-stable-nixpkgs.md
