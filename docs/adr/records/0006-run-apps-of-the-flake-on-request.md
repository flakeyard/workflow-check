---
id: ADR-0006
title: Run apps of the flake on request
status: accepted
date: 2026-11-17
supersedes: []
superseded_by: []
related: [ADR-0001, ADR-0004, ADR-0005]
affects: [".github/workflows/check.yaml", ".github/actions/flake-apps/**"]
review_by:
---

## Context

Some checks of an atom cannot run in the Nix sandbox, which has no network.
[FY-0017][fy-0017] lets an atom offer them as an app of the project's flake:
atom-markdown adds `apps.markdown-links`, which checks every link of the
project's tracked Markdown files with lychee, also those on the network. A
project runs it by hand, and its CI needs a way to run it too, on a schedule
rather than in every pull request, since the result depends on other servers.
The same step in every repository is a copy that [FY-0035][fy-0035] forbids.

What shapes the design:

- The job `flake` of every system already checks out the repository, installs
  Nix and builds the checks of the flake (`flake-checks`). The caller chooses
  the runs of `override-inputs` and workflow-check never looks at the event
  ([ADR-0005][adr-0005]).
- The flake of an atom, and of every repository whose root flake is consumed by
  others, is `./dev`, while the files it checks are those of the whole
  repository ([FY-0038][fy-0038]). With Nix 2.35, `nix run ./dev#<app>` keeps
  the working directory of the caller, and `markdown-links` changes to the root
  of the git checkout itself.
- lychee reads `GITHUB_TOKEN` for links to github.com, and has a much lower rate
  limit without it; markdown-links falls back to `GH_TOKEN`. zizmor reads
  `GH_TOKEN` or `GITHUB_TOKEN` for its online audits.
- Every check of [ADR-0001][adr-0001] is switchable and succeeds with a notice
  when it is switched off; it is never skipped.
- The steps of internal actions run their scripts through `run-step.sh` with
  only the variables of their run line ([ADR-0004][adr-0004]).
- `image-devcontainer` passes `flake: ""` and builds its checks in its own job,
  the one exception of FY-0038, so workflow-check has no flake job there.

## Decision

`check.yaml` gets the input `apps` (default `[]`), a JSON array of the names of
apps of the flake. The caller chooses the runs that run them, such as those of
its schedule:

```yaml
apps: ${{ github.event_name == 'schedule' && '["markdown-links"]' || '[]' }}
```

workflow-check does not look at the event.

A new internal action `flake-apps`, which follows ADR-0004, is the last step of
the job `flake`, after `flake-checks`, on every system of `systems`. It runs
also when the checks failed, unless the run was cancelled, so that one run
reports both. It:

- validates `apps` before Nix runs: a JSON array of names of letters, digits and
  `_.+-` that start with a letter, a digit or `_`; anything else fails with an
  error annotation;
- succeeds with a notice and runs no Nix when the list is empty;
- changes to the root of the checkout, `GITHUB_WORKSPACE`, so that every app,
  also one of `./dev`, starts in the root of the repository whose files it
  checks;
- reads the names of the apps of its system from the flake and fails, before any
  app runs, when one of the list is missing, naming every missing one;
- runs each app with `nix run --no-update-lock-file` in the order of the list,
  also after one failed, writes the result of each to the job summary, and fails
  when any failed, naming them.

The apps run with the committed `flake.lock`, without `override-inputs`: they
check the project, not the atom against its upstreams. The step gives the apps
`GH_TOKEN` and `GITHUB_TOKEN`, both `github.token` of the job `flake`, whose
only permission is `contents: read`; workflow-check takes no new secret, and an
app that needs more is out of scope. The apps get the tools of the runner as
`PATH` and `LC_ALL=C`, as every script of the actions does, and their own
dependencies from the flake.

Without a flake, `flake: ""`, there are no flake jobs to run apps. The job
`meta`, which runs in every case, validates `apps` with the internal action
`flake-apps-input` and fails when it names apps while `flake` is empty, since
the apps would otherwise not run without a word. The forms of a system and of an
output name, the `nix` of the job and the check that the flake has the names
asked for are kept once, in `lib/outputs.sh`, for `flake-checks` and
`flake-apps`; `lib/apps.sh` checks the input for both actions that read it, and
an empty value fails as malformed. `image-devcontainer`, the exception of
FY-0038, passes `flake: ""` and no `apps`, so no app runs there; its job `image`
would have to run them itself.

### Changes to ADR-0001

This record amends ADR-0001; its other decisions and constraints stand. Its
"Public API" lists also `apps`. Running apps is switched by the list itself
rather than by a boolean input: an empty list, the default, switches it off, and
the step then succeeds with a notice, as other switched-off checks do.

## Constraints

- workflow-check MUST NOT choose the event in which apps run; the caller does
  through `apps`.
- `apps` MUST be validated before any Nix command runs, and a value that is not
  a JSON array of names of the form above MUST fail with an error annotation.
- An empty `apps` MUST succeed with a notice; the step MUST NOT be skipped.
- A non-empty `apps` with an empty `flake` MUST fail in the job `meta`.
- An app of the list that the flake does not have for the system MUST fail the
  step before any app runs.
- Every app MUST run from the root of the checkout, with the committed
  `flake.lock` and `--no-update-lock-file`, on every system of `systems`.
- The step MUST NOT get a token other than `github.token` of the job `flake`,
  and the job MUST keep only `contents: read`.

## Consequences

- (+) A check that needs the network, such as the links of markdown-links, runs
  in CI through one input, not a job in every repository.
- (+) A missing app fails as a missing check does, so a removed import of an
  atom is noticed.
- (−) The apps run outside the sandbox with the token of the job, so they are
  code of the checked commit with network access; the token can only read the
  repository, and in pull requests from forks it is read-only anyway.
- (−) A run of the apps depends on other servers, so its result can change from
  week to week; callers run them on their schedule.
- (−) The apps run once per system, so a check of links makes its requests
  twice; the owner chose every system over a choice of one.
- (±) Every flake job of a caller that runs no apps emits one more notice.
- (±) `apps` is switched by an empty list rather than by a boolean input.

## Alternatives considered

- **Run the apps in the schedule only.** Simpler for callers, but workflow-check
  would decide the event, which ADR-0005 leaves to the caller.
- **One system only.** Halves the requests of a check of links, but an app that
  breaks on one architecture would pass; the owner chose every system.
- **A job of its own.** Runs once, but installs Nix and checks out the
  repository again; the job `flake` already does both.
- **Run the apps from the directory of the flake.** An app of `./dev` would see
  only the files of `dev/`, not those of the project it checks.
- **A secret input for the token.** Callers would have to pass a secret that the
  workflow does not need; `github.token` covers the rate limits.

[adr-0001]: 0001-check-pull-requests-and-pushes.md
[adr-0004]: 0004-run-the-steps-of-internal-actions-through-run-step-sh.md
[adr-0005]: 0005-override-inputs-on-a-schedule-and-forbid-configuration-files.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0035]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0035-extract-logic-that-has-two-users.md
[fy-0038]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0038-roll-out-the-atoms.md
