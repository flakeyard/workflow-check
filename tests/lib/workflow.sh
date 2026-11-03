# shellcheck shell=bash
# Static tests of a workflow: jq expressions over the workflow, read as JSON
# with mikefarah yq v4, which GitHub-hosted runners have. Source this file
# after case.sh.
# shellcheck disable=SC2034 # current is the test that report and finish count.
# shellcheck disable=SC2016 # jq expressions, not expansions.

: "${root:?}"

# References to actions that are not code of the calling repository: actions
# of this repository, and others pinned by commit.
readonly OWN_OR_PINNED='^(\$/\.github/actions/[a-z-]+|[A-Za-z0-9-]+/[A-Za-z0-9._-]+@[0-9a-f]{40})$'

# Helpers of the expressions of workflow_check.
readonly WORKFLOW_DEFS='
  def condition: (.if // "") | gsub("\\s+"; " ");
  def steps: [.jobs[] | .steps // [] | .[]];
  def uses_of($job): [.jobs[$job].steps // [] | .[] | .uses // empty];
'

# have_yq: mikefarah yq v4 is installed.
have_yq() {
  command -v yq >/dev/null && [[ $(yq --version 2>&1) == *mikefarah* ]]
}

# require_yq FILE: true when yq is installed; otherwise fails a test of FILE.
require_yq() {
  local file=$1
  have_yq && return 0
  setup
  current="$file: yq is installed"
  report "the static tests of the workflows need mikefarah yq v4; run them with: nix shell nixpkgs#yq-go -c tests/run.sh"
  finish
  return 1
}

# load_workflow FILE: print the workflow FILE of .github/workflows as JSON.
load_workflow() {
  local file=$1
  yq -o=json . "$root/.github/workflows/$file"
}

# workflow_check WORKFLOW NAME FILTER: FILTER, a jq expression over WORKFLOW,
# the JSON of load_workflow, is true.
workflow_check() {
  local workflow=$1 name=$2 filter=$3
  setup
  current=$name
  jq -e --arg own_or_pinned "$OWN_OR_PINNED" "$WORKFLOW_DEFS $filter" \
    <<<"$workflow" >/dev/null || report "not true: $filter"
  finish
}
