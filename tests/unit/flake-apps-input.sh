# shellcheck shell=bash
# Tests of flake-apps-input.

step="flake-apps-input"

for flake in "" . ./dev; do
  action_setup
  apply FLAKE="${flake}" APPS='[]'
  run_step "flake-apps-input: no apps with the flake '${flake}'" ok "${ACTIONS}/${step}" "${step}"
  expect errors 0
  finish
done

action_setup
apply FLAKE=./dev APPS='["markdown-links"]'
run_step "flake-apps-input: apps of a flake" ok "${ACTIONS}/${step}" "${step}"
expect errors 0
finish

# The apps would not run without flake jobs (ADR-0006).
action_setup
apply FLAKE= APPS='["markdown-links"]'
run_step "flake-apps-input: apps without a flake fail" fail "${ACTIONS}/${step}" "${step}"
expect message "::error::apps names apps of the flake, but flake is empty, so no flake job runs them"
finish

for apps in '' 'null' '"a"' '[1]' '["-a"]' '["a b"]' 'not json'; do
  for flake in "" ./dev; do
    action_setup
    apply FLAKE="${flake}" APPS="${apps}"
    run_step "flake-apps-input: rejects the apps '${apps}' with the flake '${flake}'" fail "${ACTIONS}/${step}" "${step}"
    expect message "::error::apps is not a JSON array of app names, such as [] or [\"markdown-links\"]"
    finish
  done
done

action_setup
apply FLAKE= APPS='["a"]'
run_hostile "flake-apps-input: earlier steps of the job run no code in it" fail "${ACTIONS}/${step}" "${step}"
expect message "flake is empty"
finish
