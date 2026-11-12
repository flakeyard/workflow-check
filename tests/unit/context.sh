# shellcheck shell=bash
# Tests of context.

step=context

# context_case NAME JOB_NAME CONTEXT: the job named JOB_NAME gets CONTEXT.
context_case() {
  local name=$1 job_name=$2 context=$3
  action_setup
  apply CHECK_RUN_ID=125414394526
  fixture "repos/$REPO/actions/jobs/125414394526" "$(jq -n --arg name "$job_name" '{name: $name}')"
  run_step "context: $name" ok "$ACTIONS/$step" "$step"
  expect output context "$context"
  finish
}

context_case "from the pending job" "check / pending" "check / required"
context_case "from the required job" "check / required" "check / required"
context_case "from a nested call" "ci / check / required" "ci / check / required"
context_case "from another caller job id" "verify / required" "verify / required"
context_case "from a job that is not called" "pending" "required"

action_setup
apply CHECK_RUN_ID=125414394526
run_step "context: a missing job fails" fail "$ACTIONS/$step" "$step"
expect message "cannot read the name of job 125414394526"
finish

action_setup
apply CHECK_RUN_ID=125414394526
fixture "repos/$REPO/actions/jobs/125414394526" '{"id":125414394526}'
run_step "context: a job without a name fails" fail "$ACTIONS/$step" "$step"
finish

action_setup
apply CHECK_RUN_ID=125414394526
fixture "repos/$REPO/actions/jobs/125414394526" "HTTP 500"
run_step "context: an API error fails" fail "$ACTIONS/$step" "$step"
finish

for id in "" "12/../34" "0"; do
  action_setup
  apply CHECK_RUN_ID="$id"
  run_step "context: rejects the check run id '$id'" fail "$ACTIONS/$step" "$step"
  expect message "not a check run id"
  finish
done

action_setup
apply CHECK_RUN_ID=125414394526
fixture "repos/$REPO/actions/jobs/125414394526" '{"name":"check / pending"}'
run_hostile "context: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect output context "check / required"
finish
