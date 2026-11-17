# shellcheck shell=bash
# Tests of flake-apps, with the stub of nix.
# shellcheck disable=SC2016 # Code spans of the summary, not expansions.
# shellcheck disable=SC2154 # work and sysbin come from case.sh and tests/lib/action.sh.

step="flake-apps"
readonly APP_TOKEN=ghs_token

# apps_setup APPS: a flake with the apps a and b.c, of which APPS are run,
# from a checkout in the directory workspace of the test.
apps_setup() {
  action_setup
  mkdir "${work}/workspace"
  apply FLAKE=./dev SYSTEM=x86_64-linux APPS="$1" GITHUB_WORKSPACE="${work}/workspace" \
    GH_TOKEN="${APP_TOKEN}" GITHUB_TOKEN="${APP_TOKEN}" NIX_APPS='["a","b.c"]'
}

apps_setup '["b.c","a"]'
run_step "flake-apps: every app runs, in the order given" ok "${ACTIONS}/${step}" "${step}"
expect call 'nix run --no-update-lock-file --option accept-flake-config false ./dev#.apps.x86_64-linux."b.c"'
expect call 'nix run --no-update-lock-file --option accept-flake-config false ./dev#.apps.x86_64-linux."a"'
order=$(sed -n 's/^nix run .*\.\("[a-z.]*"\)$/\1/p' "${work}/calls")
[[ ${order} == $'"b.c"\n"a"' ]] || report "apps ran in the order ${order}"
expect summary '| `b.c` | succeeded |'
expect summary '| `a` | succeeded |'
finish

# The apps check the files of the project from the root of the checkout, and
# get the token for the rate limits of the API.
apps_setup '["a"]'
run_step "flake-apps: an app runs from the root of the checkout with the token" ok "${ACTIONS}/${step}" "${step}"
expect call "in ${work}/workspace with GH_TOKEN=${APP_TOKEN} GITHUB_TOKEN=${APP_TOKEN}"
finish

apps_setup '["a","b.c"]'
apply NIX_FAILED=a
run_step "flake-apps: a failed app fails, and the next one still runs" fail "${ACTIONS}/${step}" "${step}"
expect message "apps that failed on x86_64-linux: a"
expect call './dev#.apps.x86_64-linux."b.c"'
expect summary '| `a` | failed |'
expect summary '| `b.c` | succeeded |'
finish

apps_setup '["a","shell","lint"]'
run_step "flake-apps: a missing app fails before any app runs" fail "${ACTIONS}/${step}" "${step}"
expect message "::error::the flake ./dev has no apps.x86_64-linux of: shell, lint"
expect no-calls
finish

apps_setup '["a"]'
apply NIX_APPS='[]'
run_step "flake-apps: a flake without apps has none of them" fail "${ACTIONS}/${step}" "${step}"
expect message "the flake ./dev has no apps.x86_64-linux of: a"
finish

apps_setup '["a"]'
apply NIX_EVAL_ERROR="attribute missing"
run_step "flake-apps: a flake that does not evaluate fails" fail "${ACTIONS}/${step}" "${step}"
expect message "cannot evaluate the apps of the flake ./dev"
expect no-calls
finish

apps_setup '["a"]'
apply NIX_STALE_LOCK=1
run_step "flake-apps: a lock file that is out of date fails" fail "${ACTIONS}/${step}" "${step}"
expect message "requires lock file changes"
expect no-calls
finish

for apps in '[]' '[ ]'; do
  apps_setup "${apps}"
  apply PATH="${sysbin}"
  run_step "flake-apps: no apps with '${apps}' succeed with a notice, without nix" ok "${ACTIONS}/${step}" "${step}"
  expect message "::notice::no apps of the flake to run on x86_64-linux"
  expect no-calls
  finish
done

# Values that are no JSON array of app names, and names that would leave the
# quotes of the attribute, be read as options or end a workflow command.
for apps in '' 'null' '"a"' '{"a":1}' '[1]' '[null]' '[["a"]]' '[""]' '["-a"]' '["--impure"]' '[".a"]' \
  '["+a"]' '["a b"]' '["a\"b"]' '["a/b"]' '["a#b"]' '["a\n"]' '["\na"]' '["é"]' '["a::error::x"]' \
  '["a\u0000b"]' 'not json'; do
  apps_setup "${apps}"
  run_step "flake-apps: rejects the apps '${apps}'" fail "${ACTIONS}/${step}" "${step}"
  expect message "::error::apps is not a JSON array of app names, such as [] or [\"markdown-links\"]"
  expect no-calls
  finish
done

if has_wide_ranges; then
  apps_setup '["é"]'
  apply_wide_locale
  run_step "flake-apps: rejects a name beyond ASCII in any locale" fail "${ACTIONS}/${step}" "${step}"
  expect message "apps is not a JSON array of app names"
  finish
fi

for flake in "../x" "./a/../.." "/abs" "github:o/r" "./dev#x" ""; do
  apps_setup '["a"]'
  apply FLAKE="${flake}"
  run_step "flake-apps: rejects the flake '${flake}'" fail "${ACTIONS}/${step}" "${step}"
  expect no-calls
  finish
done

apps_setup '["a"]'
apply SYSTEM='x86_64-linux"; y'
run_step "flake-apps: rejects a system that is not one" fail "${ACTIONS}/${step}" "${step}"
expect message "not a system"
expect no-calls
finish

# The nix of the PATH of the job, where action-setup-nix puts it.
apps_setup '["a"]'
apply PATH="${sysbin}"
run_step "flake-apps: no nix on the PATH of the job" fail "${ACTIONS}/${step}" "${step}"
expect message "no nix on the PATH of the job"
expect no-calls
finish

apps_setup '["b.c"]'
run_hostile "flake-apps: earlier steps of the job run no code in it" ok "${ACTIONS}/${step}" "${step}"
expect summary '| `b.c` | succeeded |'
finish
