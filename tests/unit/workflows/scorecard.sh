# shellcheck shell=bash
# Static tests of the Scorecard workflow of this repository.
# shellcheck disable=SC2016 # jq expressions, not expansions.

: "${root:?}"

# scorecard_test NAME FILTER: FILTER is true of scorecard.yaml.
scorecard_test() { repository_check "$scorecard_workflow" "scorecard.yaml: $1" "$2"; }

if require_yq scorecard.yaml; then
  scorecard_workflow=$(load_workflow scorecard.yaml)
  scorecard_test "workflow-scorecard is pinned by commit" \
    '.jobs.scorecard.uses | test("^flakeyard/workflow-scorecard/\\.github/workflows/scorecard\\.yaml@[0-9a-f]{40}$")'
  scorecard_test "runs on pushes to main, a schedule and dispatch only" \
    '.on | keys == ["push", "schedule", "workflow_dispatch"] and .push.branches == ["main"]'
  scorecard_test "grants nothing at the top level" '.permissions == {}'
  scorecard_test "the only job grants exactly the Scorecard permissions" \
    '(.jobs | keys == ["scorecard"]) and .jobs.scorecard.permissions == {"actions": "read", "contents": "read", "id-token": "write", "security-events": "write"}'
fi
