# shellcheck shell=bash
# Tests of flake-checks, with the stub of nix.
# shellcheck disable=SC2016 # Code spans of the summary, not expansions.
# shellcheck disable=SC2154 # sysbin comes from tests/lib/action.sh.

step="flake-checks"
readonly DEFAULT_SYSTEMS='[{"system":"x86_64-linux","runner":"ubuntu-24.04"},{"system":"aarch64-linux","runner":"ubuntu-24.04-arm"}]'

# flake_setup: a flake of both default systems with the checks a and b.
flake_setup() {
  action_setup
  apply FLAKE=. SYSTEM=x86_64-linux SYSTEMS="$DEFAULT_SYSTEMS" EXPECT_CHECKS='[]' OVERRIDE_INPUTS='{}' \
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

# Overridden inputs (ADR-0005).
readonly NIXPKGS_REF='git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05&shallow=1'
readonly HOOKS_REF='github:cachix/git-hooks.nix'

flake_setup
apply OVERRIDE_INPUTS="{\"nixpkgs\":\"$NIXPKGS_REF\",\"git-hooks\":\"$HOOKS_REF\"}" \
  NIX_OVERRIDES="--override-input nixpkgs $NIXPKGS_REF --override-input git-hooks $HOOKS_REF"
run_step "flake-checks: every command that reads the flake overrides the inputs" ok "$ACTIONS/$step" "$step"
expect call "nix build --no-update-lock-file --override-input nixpkgs $NIXPKGS_REF --override-input git-hooks $HOOKS_REF --no-link --print-build-logs --keep-going .#.checks.x86_64-linux.\"a\" .#.checks.x86_64-linux.\"b.c\""
expect message "::notice::inputs overridden on x86_64-linux: nixpkgs = $NIXPKGS_REF, git-hooks = $HOOKS_REF"
expect summary "- \`nixpkgs\`: \`$NIXPKGS_REF\`"
expect summary "- \`git-hooks\`: \`$HOOKS_REF\`"
expect summary '| `a` | built |'
finish

flake_setup
run_step "flake-checks: no overrides, no report" ok "$ACTIONS/$step" "$step"
expect notices 0
expect no-message "overridden"
finish

flake_setup
apply OVERRIDE_INPUTS='{"nixpkgs":"github:NixOS/nixpkgs"}' NIX_OVERRIDES="--override-input nixpkgs github:NixOS/nixpkgs" \
  NIX_STALE_LOCK=1
run_step "flake-checks: overrides keep the lock file as committed" fail "$ACTIONS/$step" "$step"
expect message "requires lock file changes"
expect no-calls
finish

for overrides in '[]' '"x"' 'null' 'not json' ''; do
  flake_setup
  apply OVERRIDE_INPUTS="$overrides"
  run_step "flake-checks: rejects the overrides '$overrides'" fail "$ACTIONS/$step" "$step"
  [[ -z $overrides ]] || expect message "override-inputs is not a JSON object"
  expect no-calls
  finish
done

# Names that are no names of inputs of the root, or that would end the
# argument list or a workflow command; jq writes them as JSON.
for name in '' '1a' '-a' 'a.b' 'a/b' 'a b' 'é' 'a\n' '\na' '--impure' 'a::error::x' 'a\u0000b'; do
  flake_setup
  apply OVERRIDE_INPUTS="{\"$name\":\"github:o/r\"}" NIX_SYSTEM=aarch64-linux
  run_step "flake-checks: rejects the input name \"$name\"" fail "$ACTIONS/$step" "$step"
  expect message "override-inputs: not the name of an input"
  expect no-message "Nix builds for"
  expect no-calls
  finish
done

for reference in 'path:/etc' 'file:///etc' '/etc' './dep' 'https://example.com/x.tar.gz' 'git+file:///etc' \
  'git+ssh://github.com/o/r' 'GITHUB:o/r' ' github:o/r' 'github:o/r --impure' 'github:o/r\n--impure' \
  'github:o/r\t' 'github:o/r\u0000' 'github:o/r\u007f' 'github:o/r\u00a0' 'github:o/r\u2028' ''; do
  flake_setup
  apply OVERRIDE_INPUTS="{\"nixpkgs\":\"$reference\"}" NIX_SYSTEM=aarch64-linux
  run_step "flake-checks: rejects the reference \"$reference\"" fail "$ACTIONS/$step" "$step"
  expect message "override-inputs: the reference of nixpkgs must start with git+https:// or github: and have no whitespace or control characters"
  expect no-message "Nix builds for"
  expect no-calls
  finish
done

for reference in 1 null true '["github:o/r"]' '{"url":"github:o/r"}'; do
  flake_setup
  apply OVERRIDE_INPUTS="{\"nixpkgs\":$reference}"
  run_step "flake-checks: rejects the reference $reference, not a string" fail "$ACTIONS/$step" "$step"
  expect message "override-inputs: the reference of nixpkgs must start with"
  finish
done

# Every bad pair is reported, and the escaped text ends no workflow command.
flake_setup
apply OVERRIDE_INPUTS='{"a%0A::error::x":"github:o/r","b":"path:.","c":"github:o/r"}'
run_step "flake-checks: every bad override is reported" fail "$ACTIONS/$step" "$step"
expect errors 2
expect message 'not the name of an input: "a%250A::error::x"'
expect message "the reference of b must start with"
finish

flake_setup
apply OVERRIDE_INPUTS='{"nixpkgs":"github:o/r?ref=`x`|y"}' NIX_OVERRIDES='--override-input nixpkgs github:o/r?ref=`x`|y'
run_step "flake-checks: a reference cannot leave its code span in the summary" ok "$ACTIONS/$step" "$step"
expect summary "- \`nixpkgs\`: \`github:o/r?ref='x'\\|y\`"
finish

flake_setup
apply OVERRIDE_INPUTS="{\"nixpkgs\":\"$NIXPKGS_REF\"}" NIX_OVERRIDES="--override-input nixpkgs $NIXPKGS_REF"
run_hostile "flake-checks: earlier steps run no code in a run with overrides" ok "$ACTIONS/$step" "$step"
expect summary "- \`nixpkgs\`: \`$NIXPKGS_REF\`"
finish
