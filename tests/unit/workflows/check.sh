# shellcheck shell=bash
# shellcheck disable=SC2016 # jq expressions, not expansions.
# Static tests of the product workflow: the jobs, their permissions, the
# references they use and the conditions that decide which jobs may be
# skipped.

# The jobs of the workflow, sorted.
readonly CHECK_JOBS='["flake","meta","pending","required"]'
# The permissions the caller grants; no job may ask for more.
readonly CHECK_PERMISSIONS='{"actions":"read","contents":"read","pull-requests":"read","statuses":"write"}'
# The checks of meta that an input switches, in their order.
readonly SWITCHED_CHECKS='["pr-title","renovate-config","release-tags"]'
readonly DISPATCHED="github.event_name == 'workflow_dispatch'"

# check_test NAME FILTER: FILTER is true of check.yaml.
check_test() { workflow_check "$check_workflow" "check.yaml: $1" "$2"; }

if require_yq check.yaml; then
  check_workflow=$(load_workflow check.yaml)
  check_test "no permissions at the top level" '.permissions == {}'
  check_test "only the documented jobs" \
    ".jobs | keys == $CHECK_JOBS"
  check_test "no job asks for more than the documented permissions" \
    "[.jobs[] | .permissions | to_entries[] | select(${CHECK_PERMISSIONS}[.key] != .value)] == []"
  check_test "matrix job names need no expression" \
    '[.jobs[] | select(has("strategy")) | .name // empty] == []'
  check_test "every job has a timeout" \
    '[.jobs[] | select(has("timeout-minutes") | not)] == []'
  check_test "no expression inside run" \
    '[.. | objects | .run? // empty | select(contains("${{"))] == []'
  check_test "every action is of this repository or pinned by commit" \
    '[steps[] | .uses // empty | select(test($own_or_pinned) | not)] == []'
  check_test "no secrets and no environment" \
    '(.on.workflow_call | has("secrets") | not) and ([.jobs[] | select(has("environment"))] == [])
    and ([.. | strings | select(contains("secrets."))] == [])'
  check_test "only flake checks out code, without credentials" \
    '[.jobs | to_entries[] | select(.value.steps | any(.uses // "" | test("actions/checkout"))) | .key] == ["flake"]
    and ([.jobs.flake.steps[] | select(.uses | test("actions/checkout")) | .with["persist-credentials"]] == [false])'
  check_test "flake gets no token" \
    '[.jobs.flake | .. | strings | select(test("token"; "i"))] == []'
  check_test "flake runs unless cancelled, when there is a flake" \
    '.jobs.flake | condition == "${{ !cancelled() && inputs.flake != '"''"' }}"'
  check_test "needs is a required input without a default" \
    '.on.workflow_call.inputs.needs | .required == true and (has("default") | not)'
  check_test "required needs every other job and always runs" \
    '(.jobs | keys - ["required"]) as $others
    | .jobs.required | (.needs | sort) == $others and condition == "${{ always() }}"'
  check_test "pending runs only on dispatch, and may be skipped otherwise" \
    ".jobs.pending | condition == \"\${{ $DISPATCHED }}\""
  check_test "the verdict lets exactly the skipped jobs be skipped" \
    "[.jobs.required.steps[] | select(.id == \"verdict\") | .with[\"check-may-skip\"]]
    == [\"{\\\"pending\\\": \${{ github.event_name != 'workflow_dispatch' }}, \\\"flake\\\": \${{ inputs.flake == '' }}}\"]"
  check_test "only dispatched runs post commit statuses" \
    "[.jobs[] | select(condition != \"\${{ $DISPATCHED }}\") | .steps[]
    | select(.uses == \"\$/.github/actions/commit-status\") | condition
    | select(contains(\"$DISPATCHED\") | not)] == []"
  check_test "the final status is posted on every outcome" \
    "[.jobs.required.steps[] | select(.uses == \"\$/.github/actions/commit-status\" or .id == \"context\") | condition]
    | length == 2 and all(startswith(\"\${{ always() && \"))"
  check_test "every check of meta runs also when another one failed" \
    '.jobs.meta.steps[1:] | all(condition == "${{ !cancelled() }}")'
  check_test "every check of meta is switched by a boolean input, true by default" \
    "$SWITCHED_CHECKS"' as $names
    | [.jobs.meta.steps[] | .with.enabled // empty] == [$names[] | "${{ inputs.\(.) }}"]
    and ([.on.workflow_call.inputs[$names[]] | .type == "boolean" and .default == true] | all)'
fi
