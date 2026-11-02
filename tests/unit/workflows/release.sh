# shellcheck shell=bash
# Static tests of the release workflow of this repository.
# shellcheck disable=SC2016 # jq expressions, not expansions.
# shellcheck disable=SC2034 # current is the test that report and finish count.

: "${root:?}"

# release_test NAME FILTER: FILTER is true of release.yaml.
release_test() { workflow_check "$release_workflow" "release.yaml: $1" "$2"; }

if require_yq release.yaml; then
  release_workflow=$(load_workflow release.yaml)
  release_test "workflow-release is pinned by commit" \
    '.jobs.release.uses | test("^flakeyard/workflow-release/\\.github/workflows/release\\.yaml@[0-9a-f]{40}$")'
  release_test "release pull requests are checked by the CI of this repository" \
    '.jobs.release.with | .["check-workflow"] == "check-self.yaml" and .["app-pull-requests"] == false'
  if [[ ! -f $root/.github/workflows/check-self.yaml ]]; then
    setup
    current="release.yaml: the check workflow exists"
    report "no .github/workflows/check-self.yaml"
    finish
  fi
fi
