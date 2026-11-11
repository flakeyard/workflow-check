# workflow-check

A reusable GitHub Actions workflow that checks pull requests and pushes of
flakeyard repositories and of projects generated from flakeyard templates. A
repository calls it as the last job of its check workflow. It builds the checks
of the repository's flake on every system the flake declares, after checking its
`flake.lock`, checks what only the event and the GitHub API can tell, such as
the title of a pull request, and ends with one job whose check,
`check / required`, is the only required status check of the repository.

## Usage

Call it from the check workflow, here `test.yaml`, as the last job, with the id
`check` and no `name:`, so that its final check is `check / required`:

```yaml
# .github/workflows/test.yaml
name: test

on:
  pull_request:
    types: [opened, synchronize, reopened, edited] # edited: the title check
  push:
    branches: [main, "release/v*"]
  schedule:
    - cron: "23 4 * * 1"
  workflow_dispatch: # dispatched checks of release pull requests

permissions: {}

concurrency:
  group: test-${{ github.ref }}
  # A title or description edit must not cancel a long run.
  cancel-in-progress: >-
    ${{ github.event_name == 'pull_request'
        && github.event.action != 'edited' }}

jobs:
  install: # the repository's own jobs, as many as it needs
    runs-on: ubuntu-24.04
    permissions:
      contents: read
    steps: [...]

  check:
    needs: [install] # every other job of the workflow
    # Dispatched runs post their final status on every outcome.
    if: ${{ !cancelled() || github.event_name == 'workflow_dispatch' }}
    uses: flakeyard/workflow-check/.github/workflows/check.yaml@<commit> # v0.1.0
    permissions:
      actions: read # own job name and the jobs of the run
      contents: read # repository files through the contents API, checkout
      pull-requests: read # the title of the pull request
      statuses: write # commit statuses of dispatched runs
    with:
      needs: ${{ toJSON(needs) }}
```

The caller must:

- list every other job of the workflow in the `needs` of `check` and pass
  `needs: ${{ toJSON(needs) }}`, also without other jobs, when it is `{}`; a job
  that is missing there is still running when `required` reads the jobs of the
  run, and fails it;
- let no job depend on `check`;
- run `check` with
  `if: ${{ !cancelled() || github.event_name == 'workflow_dispatch' }}`: a pull
  request run cancelled by a newer push leaves no result, and a dispatched run
  reports one on every outcome;
- not cancel a run in progress for the `pull_request` action `edited`.

Require the check `check / required` with GitHub Actions as its source in the
rulesets of the repository. Reference the workflow by full commit SHA, as above.

## Checks

- **Flake lock.** In every flake job, right after Nix is installed and before
  the flake is evaluated, [action-flake-lock][action-flake-lock] checks
  `<flake>/flake.lock`: every flakeyard input is locked to the commit of a
  release `vX.Y.Z` of the major version its `ref` names, no source is locked
  twice unless it is in `allow-duplicates`, and every input of the root is
  pinned as
  `git+https://github.com/<owner>/<repo>?ref=<ref>&rev=<commit>&shallow=1`.
  Unless `nixpkgs-eol` is `false`, it also checks the end of life of the nixpkgs
  branch of every input of the root: it warns from 30 days before it, and after
  it fails runs of the caller's `schedule` event and warns in every other run.
  The action builds its own tools and evaluates only its own flake. It reports
  every problem in the job summary and as annotations, once per system, and
  fails the job; the flake checks still run. With `flake-lock: false` or
  `flake: ""`, which also leave out the end of life, or `nixpkgs-eol: false`,
  the job `meta` emits a notice instead.
- **Flake checks.** On every system of `systems`, the job
  `flake (<system>, <runner>)` checks out the repository, installs Nix with
  [action-setup-nix](https://github.com/flakeyard/action-setup-nix), checks that
  Nix builds for the runner's own system, that the systems the flake declares in
  `checks`, `packages`, `apps`, `devShells` and `formatter` are exactly those of
  `systems`, that the flake evaluates (`nix flake check --no-build`) and that it
  has the checks of `expect-checks`. Nix reads `flake.lock` as committed and
  never updates it: a lock file that is missing or lacks an input fails. It then
  builds every check of its system and lists the result of each in the job
  summary. With `flake: ""` there are no such jobs.
- **Pull request title.** It follows Conventional Commits:
  `<type>[(<scope>)][!]: <description>`, with a type of `pr-title-types` and a
  scope of lower-case letters, digits and `._/-`. The title is read from the
  API, so a rerun after a fix of the title passes. A dispatched run checks every
  open pull request of its branch; pushes and scheduled runs have no title to
  check.
- **Renovate configuration.** `renovate.json` exists at the root, no other
  Renovate configuration does (`renovate.json5`, `.renovaterc*`,
  `.github/renovate.json*`, `.gitlab/renovate.json*`, the key `renovate` of
  `package.json`), and its `extends` lists a preset of a repository of
  `renovate-presets`.
- **Release tags.** Every preset in an `extends` of `renovate.json` and the
  template of every `.copier-answers*.yml` at the root is pinned to a tag
  `vX.Y.Z` of an immutable GitHub release: `github>owner/repo#vX.Y.Z`, and
  `_src_path` on GitHub with `_commit: vX.Y.Z`. Presets of other sources and
  templates outside GitHub fail, unless their repository is in `allow-unpinned`.
  Built-in presets of Renovate are versioned with Renovate and are not checked.

Repository files are read through the contents API at the checked commit; only
the jobs that build the flake check out the repository, and only the check of
`flake.lock` reads a file of that checkout, the lock that Nix then uses. A check
that is switched off by its input succeeds with a notice.

## Inputs

- `needs` (required): `toJSON(needs)` of the calling job.
- `caller-may-skip` (default `[]`): JSON array of the ids of the caller's jobs
  that may be skipped; any other skipped job fails `required`. The jobs of the
  run are matched to these ids by name, so a job that may be skipped has no
  `name:`.
- `flake` (default `.`): the flake whose checks are built, `.` or a path below
  the repository, such as `./dev`. `""` builds none.
- `systems` (default x86_64-linux on `ubuntu-24.04` and aarch64-linux on
  `ubuntu-24.04-arm`): JSON array of `{"system": ..., "runner": ...}`, a runner
  for every system the flake declares.
- `expect-checks` (default `[]`): JSON array of the checks the flake must have.
- `extra-substituters`, `extra-trusted-public-keys` (default `""`): binary
  caches besides `cache.nixos.org`, passed to action-setup-nix.
- `timeout-minutes` (default `60`): timeout of each flake job.
- `pr-title` (default `true`): check pull request titles.
- `pr-title-types` (default
  `feat fix docs chore ci refactor test build perf revert`): the allowed types,
  lower-case words separated by single spaces.
- `renovate-config` (default `true`): check `renovate.json`.
- `renovate-presets` (default `[]`): JSON array of `owner/repo` whose presets
  `renovate.json` must extend; empty allows any preset.
- `release-tags` (default `true`): check that presets and templates are pinned
  to immutable releases.
- `allow-unpinned` (default `[]`): JSON array of `owner/repo` whose presets and
  templates are not checked.
- `flake-lock` (default `true`): check `flake.lock` with action-flake-lock.
- `allow-duplicates` (default `[]`): JSON array of the normalized sources that
  `flake.lock` may lock more than once, such as `github.com/nixos/nixpkgs` or
  `github.com/<owner>/<repo>?dir=<dir>`, for example a second nixpkgs for a
  broken tool.
- `nixpkgs-eol` (default `true`): check the end of life of the nixpkgs branches
  of `flake.lock` with action-flake-lock.

The workflow takes no secrets and has no outputs.

## Permissions

The calling job must grant `actions: read`, `contents: read`,
`pull-requests: read` and `statuses: write`:

- `actions`: the name of the job that reports the result and the jobs of the
  run;
- `contents`: repository files through the contents API, and the checkout of the
  flake jobs;
- `pull-requests`: titles of pull requests;
- `statuses`: commit statuses of dispatched runs. In pull requests from forks,
  the token is read-only; statuses are posted only on `workflow_dispatch`.

The checks of release tags and of `flake.lock` read releases with the same
token, so they see only the repositories the token can read: a release of a
private repository of another owner reads as missing.

## Behaviour

- **Events.** `pull_request`, `push`, `schedule` and `workflow_dispatch`; any
  other event, such as `pull_request_target`, fails.
- **Required.** The job `required` fails unless every job in `needs` and every
  job of the workflow succeeded, or was skipped and may be. Jobs of the caller
  and of the workflow are told apart (`caller.<id>` and `check.<id>`), so a
  caller job may have the id of a job of the workflow. It also reads the jobs of
  the run attempt, which must list `required` itself: a job other than those of
  the workflow that has not completed is missing from `needs`, and one that
  failed, or was skipped and may not be, fails `required`, listed or not. A
  caller job named like `check / lint` is checked as any other. After **Re-run
  failed jobs**, the attempt lists every job, the reused ones with their earlier
  result.
- **Dispatched runs.** Check runs of runs started by `workflow_dispatch` do not
  count for the required checks of a pull request, so such runs post the result
  as a commit status of the same name on the checked commit: `check / pending`
  posts `pending`, and `required` posts `success` or `failure`, also when the
  run was cancelled. The context is the name of the job, read through
  `job.check_run_id`, with its last part replaced by `required`. Other runs post
  no status.
- **Order.** The checks start only after the caller's own jobs, and a dispatched
  run shows `pending` only when `check` starts; a run that never reaches `check`
  posts no status, which leaves the pull request blocked. An edit of a pull
  request runs the whole check workflow again, since the title is checked on
  `edited`.

## Requirements

GitHub-hosted Ubuntu runners, x86_64 and arm64: the steps that call the API use
their `bash`, `gh`, `jq` and GNU coreutils (`base64`, `mktemp`). Every job
starts [action-shell-lib][action-shell-lib], which fails the job on any other
runner.

## Development

The workflow in [`.github/workflows/check.yaml`](.github/workflows/check.yaml)
only composes steps. Each step's logic is a small composite action in
[`.github/actions`](.github/actions), released together with the workflow and
referenced with `$/`:

- `preflight`: the event of the caller, from a list of supported events;
- `pr-title`: the title of the pull request, or of every open pull request of a
  dispatched branch, read from the API;
- `renovate-config`: `renovate.json`, the only Renovate configuration, extends a
  preset of the given repositories;
- `release-tags`: every Renovate preset and Copier template is pinned to the tag
  of an immutable GitHub release;
- `flake-lock-notice`: a notice in `meta` when the check of `flake.lock` or its
  check of the end of life of nixpkgs is switched off, or there is no flake;
- `flake-lock-inputs`: the lock file of the flake and `allow-duplicates` as the
  newline list of action-flake-lock;
- `flake-checks`: the flake evaluates and its checks build natively, on runners
  for exactly the systems it declares;
- `context`: the context of the commit status, from the name of the job that
  runs it, read through `job.check_run_id`;
- `commit-status`: the commit status of a run started by `workflow_dispatch`;
- `required`: the verdict over the jobs of the caller and of the workflow,
  cross-checked against the jobs of the run attempt; its rules are the named
  `def`s of `required/verdict.jq`.

Each job that runs these actions calls [action-shell-lib][action-shell-lib]
once, as its first step after the checkout if it has one, and passes its output
`path` to each of them as the input `shell-lib`, which the action gives to its
script as `SHELL_LIB`; the actions do not call the library themselves
([ADR-0003](docs/adr/records/0003-shell-library-and-end-of-life.md)).

The actions run their `run.sh`, which sources modules of the library from
`SHELL_LIB`: `report.sh` reports errors, notices and lines of the job summary,
escaping the text it is given, `github/api.sh` calls the GitHub API and tells a
missing resource from an error, `github/contents.sh` reads repository files at
the checked commit and `github/forms.sh` holds the form of repository names and
lists of them. Helpers that only this repository uses are in `lib`:
`lib/github/jobs.sh` reads the name of a job and the jobs of a run attempt,
`lib/flake.sh` holds the form of the input `flake` and `lib/renovate.sh` reads
presets of a Renovate configuration.

`tests/run.sh` tests the scripts with the harness and the stubs of `gh`, `date`
and `sleep` in `internal/testing/` of the library, and the stub of `nix` in
`tests/bin`; the suites in `tests/unit` mirror the actions and the helpers and
share the helpers of this repository in `tests/lib`. The static tests of the
workflows and actions run on `workflow.sh` of `internal/testing/`.
`tests/unit/workflows/check.sh` checks the jobs of the workflow: their
permissions, references, conditions, which of them may be skipped and how they
pass the library to the actions; `tests/unit/workflows/check-self.sh` checks
that the repository's own CI calls the workflow as every caller must. They read
the workflows with mikefarah `yq` v4, which GitHub-hosted runners have, and fail
without it. The tests need the library at the commit that `check.yaml` pins:
`checks.unit` of the flake fetches it, and a direct run takes it from
`SHELL_LIB`, such as
`SHELL_LIB=<checkout> nix shell nixpkgs#yq-go -c tests/run.sh`.

The repository checks itself with
[`check-self.yaml`](.github/workflows/check-self.yaml), which calls the workflow
of the same commit through `$/`, so a pull request is checked by its own
version. Its job `fixtures` runs `flake-checks` on the flakes in
`tests/fixtures/flakes`; the step may fail, and the next step checks that it
failed exactly for the fixtures that must fail, so the run stays green. The
flake of the repository runs the tests as `checks.unit`, and checks the scripts
with shellcheck and shfmt (`checks.shell`) and the Nix files with nixfmt
(`checks.formatting`). Before a pull request, run `nix flake check`, actionlint,
zizmor, prettier, markdownlint, typos and `reuse lint`; actionlint does not yet
know the `$/` syntax and reports it as an error. The repository releases itself
with [workflow-release](https://github.com/flakeyard/workflow-release) through
[`release.yaml`](.github/workflows/release.yaml), whose release pull requests
are checked by a dispatched run of `check-self.yaml`. The weekly workflow
[`maintenance.yaml`](.github/workflows/maintenance.yaml), which is not a
required check, runs `nix run .#check-eol -- nixpkgs-eol`
([`scripts/check/eol.sh`](scripts/check/eol.sh)): it warns from 30 days before
the end of life of the nixpkgs branch in `nixpkgs-eol` and fails after it,
following
[FY-0026](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0026-stable-nixpkgs.md).
The design of the workflow is recorded in
[ADR-0001](docs/adr/records/0001-check-pull-requests-and-pushes.md) and the
check of `flake.lock` in [ADR-0002](docs/adr/records/0002-check-flake-lock.md),
under [`docs/adr`](docs/adr); the rules for callers are those of
[FY-0034](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0034-check-every-repository-with-workflow-check.md);
both follow
[FY-0009](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0009-ci-on-runners.md)
and
[FY-0030](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0030-actions-workflows-and-release-bot.md).

## Bootstrap

Following
[FY-0022](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0022-bootstrap.md),
this repository checks itself with its own workflow, but some of its checks are
not released yet. Until they are:

- actionlint, zizmor, prettier, markdownlint, typos and REUSE run locally before
  every pull request; the atoms will provide them.

## License

[MIT](LICENSE).

[action-flake-lock]: https://github.com/flakeyard/action-flake-lock
[action-shell-lib]: https://github.com/flakeyard/action-shell-lib
