# workflow-check

A reusable GitHub Actions workflow that checks pull requests and pushes of
flakeyard repositories and of projects generated from flakeyard templates. A
repository calls it as the last job of its check workflow. It builds the checks
of the repository's flake on every system the flake declares, checks what only
the event and the GitHub API can tell, such as the title of a pull request, and
ends with one job whose check, `check / required`, is the only required status
check of the repository.

The workflow is not released yet; its usage is described here with the first
release.

## Development

The workflow only composes steps. Each step's logic is a small composite action
in [`.github/actions`](.github/actions), released together with the workflow and
referenced with `$/`:

- `context`: the context of the commit status, from the name of the job that
  runs it, read through `job.check_run_id`;
- `commit-status`: the commit status of a run started by `workflow_dispatch`;
- `required`: the verdict over the jobs of the caller and of the workflow,
  cross-checked against the jobs of the run attempt; its rules are the named
  `def`s of `required/verdict.jq`.

The actions run their `run.sh` and source the helpers in `lib`: `lib/github/`
calls the GitHub API (`api.sh`, which tells a missing resource from an error,
and `jobs.sh`, which reads the name of a job and the jobs of a run attempt), and
`lib/report.sh` reports errors, warnings, notices and lines of the job summary,
escaping the text it is given.

`tests/run.sh` tests the scripts with the stub of `gh` in `tests/bin`; the
suites in `tests/unit` mirror the actions and the helpers and share the helpers
in `tests/lib`. The flake of the repository runs them as `checks.unit`, and
checks the scripts with shellcheck and shfmt (`checks.shell`) and the Nix files
with nixfmt (`checks.formatting`). Before a pull request, run `nix flake check`,
actionlint, zizmor, prettier, markdownlint, typos and `reuse lint`.

## Bootstrap

Following
[FY-0022](https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0022-bootstrap.md),
this repository has no CI checks yet. Until they are released:

- actionlint, zizmor, prettier, markdownlint, typos and REUSE run locally before
  every pull request; the atoms will provide them;
- pull request titles are checked by the reviewer; this workflow will check
  them;
- rulesets require no status checks until this workflow is released;
- OpenSSF Scorecard comes with the first release of this workflow.

## License

[MIT](LICENSE).
