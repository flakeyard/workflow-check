# shellcheck shell=bash
# Tests of flake-checks, with the stub of nix.
# shellcheck disable=SC2016 # Code spans of the summary, not expansions.
# shellcheck disable=SC2154 # sysbin comes from tests/lib/action.sh.

step="flake-checks"
readonly DEFAULT_SYSTEMS='[{"system":"x86_64-linux","runner":"ubuntu-24.04"},{"system":"aarch64-linux","runner":"ubuntu-24.04-arm"}]'

# flake_setup: a flake of both default systems with the checks a and b.
flake_setup() {
  action_setup
  apply FLAKE=. SYSTEM=x86_64-linux SYSTEMS="$DEFAULT_SYSTEMS" EXPECT_CHECKS='[]' \
    NIX_SYSTEM=x86_64-linux NIX_DECLARED='["x86_64-linux","aarch64-linux","x86_64-linux"]' \
    NIX_CHECKS='["a","b.c"]'
}

flake_setup
run_step "flake-checks: every check builds" ok "$ACTIONS/$step" "$step"
expect call 'nix build --no-update-lock-file --no-link --print-build-logs --keep-going .#.checks.x86_64-linux."a" .#.checks.x86_64-linux."b.c"'
expect summary '| `a` | built |'
expect summary '| `b.c` | built |'
finish

flake_setup
apply NIX_FAILED="b.c"
run_step "flake-checks: a failed check fails" fail "$ACTIONS/$step" "$step"
expect message "checks that failed on x86_64-linux: b.c"
expect summary '| `a` | built |'
expect summary '| `b.c` | failed |'
finish

flake_setup
apply NIX_SYSTEM=aarch64-linux
run_step "flake-checks: no emulation" fail "$ACTIONS/$step" "$step"
expect message "Nix builds for aarch64-linux on the runner of x86_64-linux"
expect no-calls
finish

flake_setup
apply NIX_DECLARED='["x86_64-linux","aarch64-linux","x86_64-darwin"]'
run_step "flake-checks: a declared system without a runner" fail "$ACTIONS/$step" "$step"
expect message "the flake declares the systems aarch64-linux, x86_64-darwin, x86_64-linux but has runners for aarch64-linux, x86_64-linux"
finish

flake_setup
apply NIX_DECLARED='["x86_64-linux"]'
run_step "flake-checks: a runner for a system that is not declared" fail "$ACTIONS/$step" "$step"
expect message "the flake declares the systems x86_64-linux but has runners for"
finish

flake_setup
apply NIX_EVAL_ERROR="attribute missing"
run_step "flake-checks: an evaluation error fails" fail "$ACTIONS/$step" "$step"
expect message "the flake . does not evaluate on x86_64-linux"
expect no-calls
finish

flake_setup
apply NIX_EVAL_ERROR="attribute missing" NIX_DECLARED='["x86_64-linux"]'
run_step "flake-checks: the flake evaluates before its systems are read" fail "$ACTIONS/$step" "$step"
expect message "the flake . does not evaluate on x86_64-linux"
expect no-message "declares the systems"
finish

flake_setup
apply NIX_STALE_LOCK=1
run_step "flake-checks: a lock file that is out of date fails" fail "$ACTIONS/$step" "$step"
expect message "requires lock file changes"
expect message "the flake . does not evaluate on x86_64-linux"
expect no-calls
finish

flake_setup
apply EXPECT_CHECKS='["a","shell"]'
run_step "flake-checks: an expected check is missing" fail "$ACTIONS/$step" "$step"
expect message "the flake . has no checks.x86_64-linux of: shell"
expect no-calls
finish

flake_setup
apply NIX_CHECKS='[]'
run_step "flake-checks: no checks to build" ok "$ACTIONS/$step" "$step"
expect message "::notice::the flake . has no checks for x86_64-linux"
expect no-calls
finish

flake_setup
apply NIX_CHECKS='["a\"; b"]'
run_step "flake-checks: check names that are not attribute names" fail "$ACTIONS/$step" "$step"
expect no-calls
finish

for flake in "../x" "./a/../.." "/abs" "github:o/r" "./dev#x" ""; do
  flake_setup
  apply FLAKE="$flake"
  run_step "flake-checks: rejects the flake '$flake'" fail "$ACTIONS/$step" "$step"
  expect no-calls
  finish
done

for systems in '[]' '{"x86_64-linux":"ubuntu-24.04"}' '[{"system":"x86_64-linux"}]'; do
  flake_setup
  apply SYSTEMS="$systems"
  run_step "flake-checks: rejects the systems $systems" fail "$ACTIONS/$step" "$step"
  expect message "systems is not a JSON array of {system, runner}"
  finish
done

flake_setup
apply FLAKE=./dev
run_step "flake-checks: a flake below the repository" ok "$ACTIONS/$step" "$step"
expect call 'nix build --no-update-lock-file --no-link --print-build-logs --keep-going ./dev#.checks.x86_64-linux."a"'
finish

flake_setup
run_hostile "flake-checks: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect summary '| `a` | built |'
finish

# The nix of the PATH of the job, where action-setup-nix puts it.
flake_setup
apply PATH="$sysbin"
run_step "flake-checks: no nix on the PATH of the job" fail "$ACTIONS/$step" "$step"
expect message "no nix on the PATH of the job"
expect no-calls
finish
