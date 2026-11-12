# shellcheck shell=bash
# Tests of preflight.

step=preflight

for event in pull_request push schedule workflow_dispatch; do
  action_setup
  apply EVENT="$event"
  run_step "preflight: accepts $event" ok "$ACTIONS/$step" "$step"
  finish
done

for event in pull_request_target workflow_run issue_comment merge_group ""; do
  action_setup
  apply EVENT="$event"
  run_step "preflight: rejects '$event'" fail "$ACTIONS/$step" "$step"
  expect message "the check workflow runs on pull_request, push, schedule and workflow_dispatch"
  finish
done

action_setup
apply EVENT=push
run_hostile "preflight: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect summary "event: \`push\`"
finish
