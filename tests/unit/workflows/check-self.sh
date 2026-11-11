# shellcheck shell=bash
# shellcheck disable=SC2016 # jq expressions, not expansions.
# Static tests of the CI of this repository: it calls the product workflow as
# the caller contract asks of every repository.

# The condition of the caller job: no result for a superseded pull request
# run, and a final status for every dispatched run.
readonly CALLER_CONDITION="\${{ !cancelled() || github.event_name == 'workflow_dispatch' }}"

# self_test NAME FILTER: FILTER is true of check-self.yaml.
self_test() { repository_check "$self_workflow" "check-self.yaml: $1" "$2"; }

if require_yq check-self.yaml; then
  self_workflow=$(load_workflow check-self.yaml)
  self_test "no permissions at the top level" '.permissions == {}'
  self_test "the fixtures call the library once and pass it to the action" \
    '(library_jobs | length == 1 and all(calls_library_once and library_runs_with_later_steps))
    and actions_get_library'
  self_test "the job check calls the product workflow of this commit, unnamed" \
    '.jobs.check | .uses == "$/.github/workflows/check.yaml" and (has("name") | not)'
  self_test "check needs every other job and passes their results" \
    '(.jobs | keys - ["check"]) as $others
    | .jobs.check | (.needs | sort) == $others and .with.needs == "${{ toJSON(needs) }}"'
  self_test "no job needs check" \
    '[.jobs[] | .needs // [] | .[] | select(. == "check")] == []'
  self_test "check runs unless cancelled, and always on dispatch" \
    ".jobs.check | condition == \"$CALLER_CONDITION\""
  self_test "check gets the permissions of the product workflow" \
    ".jobs.check.permissions == $CHECK_PERMISSIONS"
  self_test "renovate.json extends the presets of the organization" \
    '.jobs.check.with["renovate-presets"] | fromjson == ["flakeyard/renovate-config"]'
  self_test "an edit of a pull request cancels no run" \
    '.concurrency["cancel-in-progress"] | contains("github.event.action != '"'edited'"'")'
  self_test "dispatched and edited pull requests are checked" \
    '.on | has("workflow_dispatch") and (.pull_request.types | index("edited") != null)'
fi
