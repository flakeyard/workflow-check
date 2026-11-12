---
id: ADR-0004
title: Run the steps of internal actions through run-step.sh
status: accepted
date: 2026-11-12
supersedes: []
superseded_by: []
related: [ADR-0003]
affects: [".github/actions/**", "tests/**"]
review_by:
---

## Context

[ADR-0003](0003-shell-library-and-end-of-life.md) gives each internal action of
`.github/actions` the directory of [action-shell-lib][asl-0001] as the input
`shell-lib`. Each action runs `"$GITHUB_ACTION_PATH/run.sh"` from `shell: bash`,
with every variable of the job, and `run.sh` sources the modules of the library
and of `.github/actions/lib`.

An earlier step of a job can set any variable for the steps after it, through
`GITHUB_ENV` and `GITHUB_PATH`. `BASH_ENV` then runs a file before `run.sh`,
exported functions (`BASH_FUNC_name%%`) replace commands such as `jq` or
`source`, `SHELLOPTS` and `PS4` run code, `BASH_SOURCE` names another directory
to source from, and `PATH` puts other tools first. Today every step of the jobs
of `check.yaml` is pinned code of flakeyard or `actions/checkout`, but any of
them, or a later change of a job, could steer every script of the workflow, with
the token of its job.

[FY-0035][fy-0035] and [action-shell-lib ADR-0001][asl-0001] answer this threat
for consumers of the library: `run-step.sh STEP_DIR STEP [VARIABLE...]` runs the
script `STEP_DIR/STEP.sh` with `/usr/bin/env -i` and `/usr/bin/bash -p`, with
only the variables named on the run line of the step and `SHELL_LIB`, and finds
its own modules from `$0`. `step_environment` of `env.sh` then sets `PATH` to
`SYSTEM_PATH`, the tools of the runner, and keeps the `PATH` of the job in
`JOB_PATH`. action-setup-nix and action-flake-lock run every step this way. Nix
is not a tool of the runner: action-setup-nix puts it on the `PATH` of the job,
from `/nix/var/nix/profiles/default/bin`.

## Decision

Every step of an internal action runs its script through `run-step.sh` of the
library that the job passes, with an explicit list of variables:

```yaml
- shell: /usr/bin/bash --noprofile --norc -p -e -o pipefail {0}
  env:
    SHELL_LIB: ${{ inputs.shell-lib }}
    EVENT: ${{ github.event_name }}
  run: >-
    /usr/bin/bash -p "$SHELL_LIB/run-step.sh" "$GITHUB_ACTION_PATH/scripts/step"
    preflight EVENT GITHUB_STEP_SUMMARY
```

- **Layout.** The script of the action `<name>` is
  `.github/actions/<name>/scripts/step/<name>.sh`, the layout that the library
  documents for its consumers. Each internal action has one step. Helpers that
  only this repository uses stay in `.github/actions/lib`.
- **Variables.** The run line names every variable that the script reads: its
  inputs from `env`, and the variables of the runner that it needs, such as
  `GITHUB_OUTPUT`, `GITHUB_STEP_SUMMARY` and `GH_TOKEN`. A script that does not
  call the API gets no token.
- **Environment.** A script sources `env.sh` of the library and runs
  `step_environment` before any command that is not a builtin. It finds its own
  files from `$0`, never from `BASH_SOURCE`. `gh`, `jq` and coreutils come from
  `SYSTEM_PATH`.
- **Nix.** `flake-checks`, the only script that runs Nix, gets `PATH` and runs
  the `nix` that `job_tool` of `env.sh` finds on `JOB_PATH`, by its absolute
  path; it also gets `HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME`, where Nix
  keeps the token that action-setup-nix configures and its cache. Every other
  tool of that script still comes from `SYSTEM_PATH`.
- **Tests.** The unit tests run each script as its step does, with `run_step` of
  `internal/testing/consumer/step.sh` of the pinned library: through
  `run-step.sh` of a copy of that library, with only the variables of its run
  line and of the stubs, so that a variable missing from the run line fails
  them. For each action, `run_hostile` gives the step a hostile environment:
  `BASH_ENV`, exported functions, `SHELLOPTS` and `PS4` that run code, and a
  `BASH_SOURCE` that names a directory of hostile modules; none of it may run.
  `check_action_steps` of the library checks that every step of an internal
  action has the shell and run line above, with every variable of its `env`
  named on its run line.

### Changes to ADR-0003

This record amends ADR-0003; its other decisions and constraints stand. In
"Shell library", the internal actions get the output `path` of the library as
the input `shell-lib`, which their `action.yml` gives to `run-step.sh` as the
variable `SHELL_LIB`, in place of giving it to `run.sh`.

## Constraints

- Every step of an internal action `<name>` MUST run
  `/usr/bin/bash -p "$SHELL_LIB/run-step.sh"` with the arguments
  `"$GITHUB_ACTION_PATH/scripts/step" <name> [VARIABLE...]`, from
  `shell: /usr/bin/bash --noprofile --norc -p -e -o pipefail {0}`, with
  `SHELL_LIB` set to `${{ inputs.shell-lib }}` in its `env`.
- The run line MUST name every variable of the step's `env` other than
  `SHELL_LIB`, and every variable of the runner that the script reads. A step
  MUST NOT get `GH_TOKEN` unless its script calls the API.
- A script MUST source `env.sh` of the library and run `step_environment` before
  it runs anything but builtins, and MUST find its own files from `$0`, not from
  `BASH_SOURCE`.
- Only `flake-checks` MAY get `PATH`, and it MUST run Nix by the absolute path
  that it finds on `JOB_PATH`; every other command of a script MUST come from
  `SYSTEM_PATH`.
- The unit tests MUST run every script through `run-step.sh` with only the
  variables of its run line and of the stubs, and MUST check for every action
  that `BASH_ENV`, exported functions, `SHELLOPTS`, `PS4` and `BASH_SOURCE` set
  by earlier steps run nothing.

## Consequences

- (+) No step of the job before an internal action can run code in it or change
  the tools it runs, except through the variables of the dynamic loader.
- (+) The variables that each script sees, the token included, are visible in
  its `action.yml`, where a review sees them.
- (+) Internal actions follow the same contract as action-setup-nix and
  action-flake-lock, so one review of the library covers all of them.
- (−) Variables of the dynamic loader, such as `LD_PRELOAD`, still reach the
  first `bash` of every step; GitHub does not block them.
- (−) A script that needs a new variable of the runner fails until its run line
  names it; the tests catch it only where they cover the code that reads it.
- (−) The scripts move one directory deeper, so their paths change.
- (±) The tests need mikefarah `yq` to read the run lines, as the static tests
  of the workflows already do.

## Alternatives considered

- **Keep `run.sh` as the script of the step.** `run-step.sh` takes any
  `STEP_DIR`, so `"$GITHUB_ACTION_PATH" run` would work with fewer moves, but it
  leaves the layout that the library and its test helpers document, and each
  consumer would test its run lines with a form of its own.
- **Unset the dangerous variables in each script.** A script cannot undo
  `BASH_ENV` or a function that ran before its first line, and a list of
  variables to drop is never complete.
- **Run each internal action with `bash -p` only.** Stops `BASH_ENV` and
  exported functions, but leaves `PATH`, `BASH_SOURCE` and every other variable
  of the job to the script.

[asl-0001]:
  https://github.com/flakeyard/action-shell-lib/blob/main/docs/adr/records/0001-shell-library.md
[fy-0035]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0035-extract-logic-that-has-two-users.md
