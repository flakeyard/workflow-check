# shellcheck shell=bash
# Static tests of a workflow: jq expressions over the workflow, with the
# helpers below, through yaml_check of internal/testing of the shell library.
# Source this file after yaml.sh.
# shellcheck disable=SC2016 # jq expressions, not expansions.
# shellcheck disable=SC2034 # The suites read CHECK_PERMISSIONS.

# References to actions that are not code of the calling repository: actions
# of this repository, and others pinned by commit.
readonly OWN_OR_PINNED='^(\$/\.github/actions/[a-z-]+|[A-Za-z0-9-]+/[A-Za-z0-9._-]+@[0-9a-f]{40})$'

# The permissions a caller grants the check workflow; no job of it may ask for
# more.
readonly CHECK_PERMISSIONS='{"actions":"read","contents":"read","pull-requests":"read","statuses":"write"}'

# Helpers of the expressions of workflow_check. A job that runs an action of
# this repository calls the library once, as its first step after the
# checkout if it has one, with the id lib, and passes its path to every such
# action (ADR-0003). Its condition is at least as permissive as that of any
# later step: always() over !cancelled() over none.
readonly WORKFLOW_DEFS='
  def condition: (.if // "") | gsub("\\s+"; " ");
  def steps: [.jobs[] | .steps // [] | .[]];
  def uses_of($job): [.jobs[$job].steps // [] | .[] | .uses // empty];
  def own_action: (.uses // "") | startswith("$/.github/actions/");
  def library: (.uses // "") | startswith("flakeyard/action-shell-lib@");
  def library_index: if (.steps[0].uses // "") | startswith("actions/checkout@") then 1 else 0 end;
  def calls_library_once:
    library_index as $index
    | (.steps | map(library) | indices(true)) == [$index] and .steps[$index].id == "lib";
  def library_jobs: [.jobs[] | select(.steps // [] | any(own_action))];
  def run_rank:
    condition as $condition
    | if $condition | contains("always()") then 2
      elif $condition | contains("!cancelled()") then 1
      else 0 end;
  def library_runs_with_later_steps:
    library_index as $index
    | (.steps[$index] | run_rank) >= ([.steps[$index + 1:][] | run_rank] | max // 0);
  def actions_get_library:
    [steps[] | select(own_action) | .with["shell-lib"]] | all(. == "${{ steps.lib.outputs.path }}");
'

# load_workflow FILE: print the workflow FILE of .github/workflows as JSON.
load_workflow() {
  local file=$1
  load_yaml ".github/workflows/$file"
}

# workflow_check WORKFLOW NAME FILTER: FILTER, a jq expression over WORKFLOW,
# the JSON of load_workflow, with the helpers of WORKFLOW_DEFS, is true.
workflow_check() {
  local workflow=$1 name=$2 filter=$3
  yaml_check "$workflow" "$name" "$WORKFLOW_DEFS $filter" --arg own_or_pinned "$OWN_OR_PINNED"
}
