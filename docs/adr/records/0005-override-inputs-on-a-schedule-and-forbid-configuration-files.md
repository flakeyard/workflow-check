---
id: ADR-0005
title:
  Override inputs on a schedule and forbid configuration files of atom tools
status: accepted
date: 2026-11-12
supersedes: []
superseded_by: []
related: [ADR-0001, ADR-0002, ADR-0004]
affects: [".github/workflows/check.yaml", ".github/actions/**"]
review_by:
---

## Context

Two decisions of flakeyard ask `check.yaml` for a new input each.

[FY-0017][fy-0017] requires the tests of every atom to run on a schedule against
current upstream revisions. [FY-0038][fy-0038] puts that logic once, in
workflow-check: it takes a map of inputs to override while it builds the checks,
the `test.yaml` of every atom passes the current branches of nixpkgs,
treefmt-nix and git-hooks.nix on its weekly schedule and nothing otherwise, and
the lock file stays unchanged and is still checked. The same job in every atom
would be a copy that [FY-0035][fy-0035] forbids.

[FY-0037][fy-0037] lets a project replace the default configuration of an atom
tool by a file at the tool's standard path at the root. flakeyard's own
repositories keep no such files; their exceptions are inline comments, such as
`# zizmor: ignore[<audit>]`. A pull request that adds such a file can switch off
a check while the required check stays green, so FY-0037 requires workflow-check
to offer a check that fails on these files, which flakeyard's repositories
switch on.

What shapes the design:

- The job `flake` already installs Nix, checks `flake.lock` with
  action-flake-lock before any evaluation ([ADR-0002](0002-check-flake-lock.md))
  and runs every Nix command of `flake-checks` with `--no-update-lock-file`, as
  [FY-0016][fy-0016] requires of CI.
- With Nix 2.35, `--override-input NAME REF` together with
  `--no-update-lock-file` evaluates and builds with the overridden input and
  leaves `flake.lock` unchanged.
- The inputs of `check.yaml` are data of the caller, written in its own
  `test.yaml`, and the flake jobs run with `contents: read` only. A pull request
  can change both, so the inputs are still validated before they reach a command
  line.
- The checks of the job `meta` read repository files through the contents API at
  the checked commit and check out nothing ([ADR-0001][adr-0001]).
  `lib/github/directory.sh` lists a directory with one request.
- Atoms declare no options of their own ([FY-0017][fy-0017]), and consumers of
  the atoms may keep configuration files (FY-0037), so an atom cannot tell
  flakeyard's repositories from other projects.

## Decision

`check.yaml` gets two inputs, each a minor addition to its public API.

### Overridden inputs

`override-inputs` (default `{}`) is a JSON object that maps the name of a root
input of the checked flake to a flake reference, such as:

```json
{
  "nixpkgs": "git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05&shallow=1",
  "git-hooks": "git+https://github.com/cachix/git-hooks.nix?ref=master&shallow=1"
}
```

An atom passes such a map when `github.event_name == 'schedule'` and `{}` in
every other run.

The job `flake` passes the map to `flake-checks`, which adds
`--override-input NAME REF` for each pair to every Nix command that reads the
flake, next to `--no-update-lock-file`: the evaluation, the systems, the names
of the checks and their builds. `flake.lock` stays as committed, and
action-flake-lock checks it before the evaluation, as in every other run.
workflow-check does not look at the event: the caller chooses when to override,
and the atoms do so only in runs of their `schedule`.

`flake-checks` validates the map before it runs Nix and fails with an error
annotation on anything else:

- the value is a JSON object, empty or not;
- every name has the form of a flake input name, `^[A-Za-z_][A-Za-z0-9_-]*$`;
  only inputs of the root can be overridden;
- every reference starts with `git+https://` or `github:` and has no whitespace
  or control characters; `path:`, `file:` and every other scheme fail.

A run with overrides says so: each flake job emits a notice that lists every
overridden input with its reference, and writes the same list above the table of
its checks in the job summary. Both are escaped as any other text that comes
from the caller. A run without overrides reports nothing new.

### Configuration files of atom tools

`forbid-tool-configs` (default `false`) switches a check of the job `meta`, in
an internal action `tool-configs` that follows [ADR-0004][adr-0004]. When it is
`true`, the action lists, through the contents API at the checked commit, the
directories that hold the standard root paths of atom tools, and fails when an
entry of any type exists at one of them. Its error names each file and the
alternative: delete the file and use the tool's inline comment for the
exception. When it is `false`, the action succeeds with a notice, as other
switched-off checks do.

The paths are data of this repository, in a file next to the script of the
action, one path per line, grouped by the atom that owns the tool. The list
grows with each released atom. It starts with the paths of atom-workflows:

- `.github/actionlint.yaml`, `.github/actionlint.yml`;
- `.github/zizmor.yml`, `.github/zizmor.yaml`, `zizmor.yml`, `zizmor.yaml`.

The default is `false`, an exception to the rule of ADR-0001 that every check is
`true` by default: only flakeyard's own repositories must keep no such files
(FY-0037), and every other caller may replace the default configurations of the
atoms.

The switch lives in the `test.yaml` of the checked repository. It catches files
added by accident and makes a deliberate change visible in the diff of
`test.yaml`, where a reviewer sees it; it does not stop a maintainer who wants
to bypass it.

### Changes to ADR-0001

This record amends ADR-0001; its other decisions and constraints stand. Its
"Public API" lists also `override-inputs` and `forbid-tool-configs`. The
constraint that every check is switchable by its own boolean input, `true` by
default, holds for `forbid-tool-configs` with the default `false`.

## Constraints

- `override-inputs` MUST be validated before any Nix command runs: a JSON object
  whose names have the form of flake input names and whose references start with
  `git+https://` or `github:` and contain no whitespace or control characters.
  Anything else MUST fail with an error annotation.
- Every Nix command of `flake-checks` that reads the flake MUST get the same
  overrides, and MUST keep `--no-update-lock-file`.
- The check of `flake.lock` MUST still run before the evaluation and MUST check
  the committed lock, also in runs with overrides.
- A run with overrides MUST emit a notice and a summary that list every
  overridden input with its reference.
- workflow-check MUST NOT choose the event in which overrides apply; the caller
  does.
- The check of `forbid-tool-configs` MUST read the repository through the
  contents API at the checked commit and MUST NOT check out code.
- The paths of `forbid-tool-configs` MUST be kept as data in this repository,
  and every released atom MUST add the standard root paths of its tools to it.
- A failure of `forbid-tool-configs` MUST name each file found and the
  inline-comment alternative. `forbid-tool-configs: false` MUST succeed with a
  notice.

## Consequences

- (+) The scheduled tests of every atom against current upstreams are one input
  in their `test.yaml`, not a job in each atom.
- (+) A scheduled run checks the committed `flake.lock` as any other run, and
  leaves it unchanged.
- (+) An accidental configuration file in a flakeyard repository fails the pull
  request that adds it, before the merge.
- (+) A repository that switches the check off does it in the diff of its
  `test.yaml`.
- (−) A run with overrides fetches unlocked revisions, so its result changes
  from week to week and cannot be reproduced from the commit alone.
- (−) Checks built with overrides miss the binary cache and take longer.
- (−) The list of paths has to follow the atoms by hand; a path missing from it
  is not checked.
- (−) The check does not protect against a maintainer who switches it off in
  `test.yaml`.
- (±) `forbid-tool-configs` is the only check whose default is `false`.
- (±) Only `git+https://` and `github:` references can be overridden; another
  scheme needs a change of this repository.

## Alternatives considered

- **A scheduled job in every atom.** The same logic ten times, which
  [FY-0035][fy-0035] forbids.
- **A separate action for the overrides.** It would install Nix and check the
  lock a second time; the job `flake` already does both.
- **The check of configuration files in the evaluation of each atom.** Atoms
  declare no options ([FY-0017][fy-0017]), so they cannot tell flakeyard's
  repositories from projects that may keep the files.
- **An audit of the organization in `.github`.** It finds the files only after
  they are merged.

[adr-0001]: 0001-check-pull-requests-and-pushes.md
[adr-0004]: 0004-run-the-steps-of-internal-actions-through-run-step-sh.md
[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0035]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0035-extract-logic-that-has-two-users.md
[fy-0037]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0037-atoms-ship-default-configs-that-projects-replace.md
[fy-0038]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0038-roll-out-the-atoms.md
