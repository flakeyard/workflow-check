# shellcheck shell=bash
# Tests of required.
# shellcheck disable=SC2016 # Code spans of the summary, not expansions.

step=required
attempt_path="repos/o/r/actions/runs/7/attempts/2/jobs?per_page=100"

# The job of the verdict in the jobs of the attempt.
readonly OWN_JOB='{"name":"check / required","status":"in_progress","conclusion":null}'
# Jobs of the attempt: the caller's install and this workflow's jobs.
readonly ATTEMPT_DONE='{"jobs":[
  {"name":"install","status":"completed","conclusion":"success"},
  {"name":"check / pending","status":"completed","conclusion":"skipped"},
  {"name":"check / meta","status":"completed","conclusion":"success"},
  {"name":"check / flake (x86_64-linux, ubuntu-24.04)","status":"completed","conclusion":"success"},
  '"$OWN_JOB"']}'
# check_needs META: the needs of the job required, with meta's result META.
check_needs() {
  jq -cn --arg meta "$1" '{pending: {result: "skipped", outputs: {}},
    meta: {result: $meta, outputs: {}}, flake: {result: "success", outputs: {}}}'
}

# required_setup: a pull request run whose jobs all succeeded.
required_setup() {
  action_setup
  apply RUN_ID=7 RUN_ATTEMPT=2 CHECK_RUN_ID=99 \
    CALLER='{"install":{"result":"success","outputs":{}}}' \
    CHECK="$(check_needs success)" \
    CALLER_MAY_SKIP='[]' CHECK_MAY_SKIP='{"pending":true,"flake":true}'
  fixture "repos/$REPO/actions/jobs/99" '{"name":"check / required"}'
  fixture "$attempt_path" "$ATTEMPT_DONE"
}

required_setup
run_step "required: every job succeeded" ok "$ACTIONS/$step" "$step"
expect summary '| `caller.install` | `success` |'
expect summary '| `check.pending` | `skipped` |'
finish

required_setup
apply CALLER='{}'
run_step "required: a caller without jobs passes {}" ok "$ACTIONS/$step" "$step"
finish

# A needs input that is not a needs context.
for caller in "" "null" "[]" '{"install":"success"}' '{"install":{"outputs":{}}}' "{"; do
  required_setup
  apply CALLER="$caller"
  run_step "required: rejects the needs '$caller'" fail "$ACTIONS/$step" "$step"
  expect message "the input needs is missing or malformed"
  finish
done

required_setup
apply CALLER='{"install":{"result":"failure","outputs":{}}}'
run_step "required: a failed caller job fails" fail "$ACTIONS/$step" "$step"
expect message "jobs that did not succeed: caller.install: failure"
finish

required_setup
apply CALLER='{"install":{"result":"cancelled","outputs":{}}}'
run_step "required: a cancelled caller job fails" fail "$ACTIONS/$step" "$step"
expect message "caller.install: cancelled"
finish

required_setup
apply CALLER='{"install":{"result":"skipped","outputs":{}}}'
run_step "required: a skipped caller job fails unless it may be skipped" fail "$ACTIONS/$step" "$step"
expect message "caller.install: skipped"
finish

required_setup
apply CALLER='{"install":{"result":"skipped","outputs":{}}}' CALLER_MAY_SKIP='["install"]'
run_step "required: a caller job may be skipped" ok "$ACTIONS/$step" "$step"
finish

required_setup
apply CHECK="$(check_needs skipped)"
run_step "required: a skipped job of this workflow fails unless it may be skipped" fail "$ACTIONS/$step" "$step"
expect message "check.meta: skipped"
finish

required_setup
apply CHECK_MAY_SKIP='{"pending":false,"flake":true}'
run_step "required: pending may not be skipped on dispatch" fail "$ACTIONS/$step" "$step"
expect message "check.pending: skipped"
finish

required_setup
apply CALLER='{"meta":{"result":"failure","outputs":{}}}' CALLER_MAY_SKIP='["meta"]'
apply CHECK="$(check_needs success)"
run_step "required: caller and own jobs of one id are told apart" fail "$ACTIONS/$step" "$step"
expect message "caller.meta: failure"
expect no-message "check.meta: success,"
finish

required_setup
fixture "$attempt_path" '{"jobs":[
  {"name":"install","status":"completed","conclusion":"success"},
  {"name":"lint","status":"in_progress","conclusion":null},
  {"name":"check / required","status":"in_progress","conclusion":null}]}'
run_step "required: a job still running is not in needs" fail "$ACTIONS/$step" "$step"
expect message "run.lint: in_progress, not in needs of the check job"
finish

required_setup
fixture "$attempt_path" '{"jobs":[
  {"name":"install","status":"completed","conclusion":"success"},
  {"name":"lint","status":"completed","conclusion":"timed_out"},
  '"$OWN_JOB"']}'
run_step "required: a failed job outside needs fails" fail "$ACTIONS/$step" "$step"
expect message "run.lint: timed_out"
finish

# A job that its if: skipped, forgotten in needs.
for conclusion in skipped neutral; do
  required_setup
  fixture "$attempt_path" '{"jobs":[
    {"name":"install","status":"completed","conclusion":"success"},
    {"name":"lint","status":"completed","conclusion":"'"$conclusion"'"},
    '"$OWN_JOB"']}'
  run_step "required: a job outside needs that is $conclusion fails" fail "$ACTIONS/$step" "$step"
  expect message "run.lint: $conclusion, not in caller-may-skip"
  finish
done

required_setup
apply CALLER='{"install":{"result":"skipped","outputs":{}}}' CALLER_MAY_SKIP='["install"]'
fixture "$attempt_path" '{"jobs":[{"name":"install","status":"completed","conclusion":"skipped"},
  '"$OWN_JOB"']}'
run_step "required: a job that may be skipped is matched by its name in the attempt" ok "$ACTIONS/$step" "$step"
expect summary '| `caller.install` | `skipped` |'
finish

required_setup
apply CALLER_MAY_SKIP='["lint"]'
fixture "$attempt_path" '{"jobs":[{"name":"lint (a, b)","status":"completed","conclusion":"skipped"},
  '"$OWN_JOB"']}'
run_step "required: a skipped matrix job is matched without its values" ok "$ACTIONS/$step" "$step"
finish

required_setup
apply CALLER_MAY_SKIP='["lint"]'
fixture "$attempt_path" '{"jobs":[{"name":"Lint","status":"completed","conclusion":"skipped"},
  '"$OWN_JOB"']}'
run_step "required: a skipped job named other than its id fails" fail "$ACTIONS/$step" "$step"
expect message "run.Lint: skipped, not in caller-may-skip"
finish

required_setup
fixture "$attempt_path" '{"jobs":[{"name":"install","status":"completed","conclusion":"success"},
  '"$OWN_JOB"']}'
next_page "$attempt_path" 2 '{"jobs":[{"name":"docs","status":"queued","conclusion":null}]}'
run_step "required: every page of the attempt is read" fail "$ACTIONS/$step" "$step"
expect message "run.docs: queued, not in needs of the check job"
finish

# A caller job whose name starts like the jobs of this workflow.
for case in 'completed "failure"' 'in_progress null'; do
  read -r status conclusion <<<"$case"
  required_setup
  fixture "$attempt_path" '{"jobs":[
    {"name":"check / lint","status":"'"$status"'","conclusion":'"$conclusion"'},
    '"$OWN_JOB"']}'
  run_step "required: a caller job named check / lint fails, $status" fail "$ACTIONS/$step" "$step"
  expect message "run.check / lint: "
  finish
done

required_setup
fixture "$attempt_path" '{"jobs":[]}'
run_step "required: the attempt without the job of the verdict fails" fail "$ACTIONS/$step" "$step"
expect message "run.check / required: missing from the jobs of the attempt"
finish

required_setup
apply CHECK_MAY_SKIP='{"pending":true,"lint":true}'
run_step "required: check-may-skip names only the needs of required" fail "$ACTIONS/$step" "$step"
expect message "check-may-skip names jobs that are not in the needs of the job required"
finish

# The delay restates _API_RETRY_DELAY of the library as an independent oracle.
required_setup
transient_failures "$attempt_path" 1
run_step "required: a transient error of the jobs of the attempt is retried" ok "$ACTIONS/$step" "$step"
expect sleeps 5
finish

required_setup
fixture "$attempt_path" "HTTP 500"
run_step "required: an API error fails" fail "$ACTIONS/$step" "$step"
expect message "cannot read the jobs of attempt 2 of run 7"
finish

required_setup
fixture "repos/$REPO/actions/jobs/99" '{"name":"required"}'
run_step "required: fails outside a called workflow" fail "$ACTIONS/$step" "$step"
finish

required_setup
apply CALLER_MAY_SKIP='"install"'
run_step "required: rejects a caller-may-skip that is not a list" fail "$ACTIONS/$step" "$step"
finish

required_setup
apply CALLER='{"x\n::warning::forged":{"result":"failure"}}'
run_step "required: job ids are escaped" fail "$ACTIONS/$step" "$step"
expect message "caller.x%0A::warning::forged: failure"
expect warnings 0
finish

required_setup
run_hostile "required: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect summary '| `caller.install` | `success` |'
finish
