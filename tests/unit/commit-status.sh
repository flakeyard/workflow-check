# shellcheck shell=bash
# Tests of commit-status.

script=.github/actions/commit-status/run.sh

# status_setup STATE: a status of STATE for the context check / required.
status_setup() {
  action_setup
  apply STATE="$1" CONTEXT="check / required" RUN_URL=https://github.com/o/r/actions/runs/1
}

for state in pending success failure; do
  status_setup "$state"
  run "commit-status: posts $state" ok "$script"
  expect call "POST repos/$REPO/statuses/$SHA state=$state context=check / required target_url=https://github.com/o/r/actions/runs/1 description=GitHub Actions run"
  finish
done

status_setup error
run "commit-status: rejects another state" fail "$script"
expect no-calls
finish

status_setup success
apply CONTEXT=""
run "commit-status: rejects an empty context" fail "$script"
expect no-calls
finish

status_setup success
apply FAIL_ON="POST repos/$REPO/statuses/$SHA 403"
run "commit-status: a refused status fails" fail "$script"
finish
