# shellcheck shell=bash
# Tests of commit-status.

step=commit-status

# status_setup STATE: a status of STATE for the context check / required.
status_setup() {
  action_setup
  apply STATE="$1" CONTEXT="check / required" RUN_URL=https://github.com/o/r/actions/runs/1
}

for state in pending success failure; do
  status_setup "$state"
  run_step "commit-status: posts $state" ok "$ACTIONS/$step" "$step"
  expect call "POST repos/$REPO/statuses/$SHA state=$state context=check / required target_url=https://github.com/o/r/actions/runs/1 description=GitHub Actions run"
  finish
done

status_setup error
run_step "commit-status: rejects another state" fail "$ACTIONS/$step" "$step"
expect no-calls
finish

status_setup success
apply CONTEXT=""
run_step "commit-status: rejects an empty context" fail "$ACTIONS/$step" "$step"
expect no-calls
finish

status_setup success
apply FAIL_ON="POST repos/$REPO/statuses/$SHA 403"
run_step "commit-status: a refused status fails" fail "$ACTIONS/$step" "$step"
finish

status_setup pending
run_hostile "commit-status: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect call "POST repos/$REPO/statuses/$SHA state=pending context=check / required"
finish
