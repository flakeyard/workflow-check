# shellcheck shell=bash
# Tests of flake-checks, with the stub of nix.
# shellcheck disable=SC2016 # Code spans of the summary, not expansions.

script="flake-checks/run.sh"
readonly DEFAULT_SYSTEMS='[{"system":"x86_64-linux","runner":"ubuntu-24.04"},{"system":"aarch64-linux","runner":"ubuntu-24.04-arm"}]'

# flake_setup: a flake of both default systems with the checks a and b.
flake_setup() {
  setup
  apply FLAKE=. SYSTEM=x86_64-linux SYSTEMS="$DEFAULT_SYSTEMS" EXPECT_CHECKS='[]' \
    NIX_SYSTEM=x86_64-linux NIX_DECLARED='["x86_64-linux","aarch64-linux","x86_64-linux"]' \
    NIX_CHECKS='["a","b.c"]'
}

flake_setup
run "flake-checks: every check builds" ok "$script"
expect call 'nix build --no-update-lock-file --no-link --print-build-logs --keep-going .#.checks.x86_64-linux."a" .#.checks.x86_64-linux."b.c"'
expect summary '| `a` | built |'
expect summary '| `b.c` | built |'
finish

flake_setup
apply NIX_FAILED="b.c"
run "flake-checks: a failed check fails" fail "$script"
expect message "checks that failed on x86_64-linux: b.c"
expect summary '| `a` | built |'
expect summary '| `b.c` | failed |'
finish

flake_setup
apply NIX_SYSTEM=aarch64-linux
run "flake-checks: no emulation" fail "$script"
expect message "Nix builds for aarch64-linux on the runner of x86_64-linux"
expect no-calls
finish

flake_setup
apply NIX_DECLARED='["x86_64-linux","aarch64-linux","x86_64-darwin"]'
run "flake-checks: a declared system without a runner" fail "$script"
expect message "the flake declares the systems aarch64-linux, x86_64-darwin, x86_64-linux but has runners for aarch64-linux, x86_64-linux"
finish

flake_setup
apply NIX_DECLARED='["x86_64-linux"]'
run "flake-checks: a runner for a system that is not declared" fail "$script"
expect message "the flake declares the systems x86_64-linux but has runners for"
finish

flake_setup
apply NIX_EVAL_ERROR="attribute missing"
run "flake-checks: an evaluation error fails" fail "$script"
expect message "the flake . does not evaluate on x86_64-linux"
expect no-calls
finish

flake_setup
apply NIX_EVAL_ERROR="attribute missing" NIX_DECLARED='["x86_64-linux"]'
run "flake-checks: the flake evaluates before its systems are read" fail "$script"
expect message "the flake . does not evaluate on x86_64-linux"
expect no-message "declares the systems"
finish

flake_setup
apply NIX_STALE_LOCK=1
run "flake-checks: a lock file that is out of date fails" fail "$script"
expect message "requires lock file changes"
expect message "the flake . does not evaluate on x86_64-linux"
expect no-calls
finish

flake_setup
apply EXPECT_CHECKS='["a","shell"]'
run "flake-checks: an expected check is missing" fail "$script"
expect message "the flake . has no checks.x86_64-linux of: shell"
expect no-calls
finish

flake_setup
apply NIX_CHECKS='[]'
run "flake-checks: no checks to build" ok "$script"
expect message "::notice::the flake . has no checks for x86_64-linux"
expect no-calls
finish

flake_setup
apply NIX_CHECKS='["a\"; b"]'
run "flake-checks: check names that are not attribute names" fail "$script"
expect no-calls
finish

for flake in "../x" "./a/../.." "/abs" "github:o/r" "./dev#x" ""; do
  flake_setup
  apply FLAKE="$flake"
  run "flake-checks: rejects the flake '$flake'" fail "$script"
  expect no-calls
  finish
done

for systems in '[]' '{"x86_64-linux":"ubuntu-24.04"}' '[{"system":"x86_64-linux"}]'; do
  flake_setup
  apply SYSTEMS="$systems"
  run "flake-checks: rejects the systems $systems" fail "$script"
  expect message "systems is not a JSON array of {system, runner}"
  finish
done

flake_setup
apply FLAKE=./dev
run "flake-checks: a flake below the repository" ok "$script"
expect call 'nix build --no-update-lock-file --no-link --print-build-logs --keep-going ./dev#.checks.x86_64-linux."a"'
finish
