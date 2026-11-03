# shellcheck shell=bash
# Tests of preflight.

script=preflight/run.sh

for event in pull_request push schedule workflow_dispatch; do
  setup
  apply EVENT="$event"
  run "preflight: accepts $event" ok "$script"
  finish
done

for event in pull_request_target workflow_run issue_comment merge_group ""; do
  setup
  apply EVENT="$event"
  run "preflight: rejects '$event'" fail "$script"
  expect message "the check workflow runs on pull_request, push, schedule and workflow_dispatch"
  finish
done
