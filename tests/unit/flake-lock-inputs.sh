# shellcheck shell=bash
# Tests of flake-lock-inputs.
# shellcheck disable=SC2154 # work is the directory of the test, from setup.

step="flake-lock-inputs"

# inputs_setup FLAKE ALLOW_DUPLICATES: the inputs of the action.
inputs_setup() {
  action_setup
  apply FLAKE="$1" ALLOW_DUPLICATES="$2"
}

# The lock file of every form of flake.
for flake_and_path in ".:flake.lock" "./dev:dev/flake.lock" "./a/b.c:a/b.c/flake.lock"; do
  inputs_setup "${flake_and_path%%:*}" '[]'
  run_step "flake-lock-inputs: the lock file of ${flake_and_path%%:*}" ok "$ACTIONS/$step" "$step"
  expect output path "${flake_and_path#*:}"
  expect_lines allow-duplicates ""
  finish
done

inputs_setup . '["github.com/nixos/nixpkgs","github.com/o/r?dir=sub"]'
run_step "flake-lock-inputs: one source per line" ok "$ACTIONS/$step" "$step"
expect_lines allow-duplicates $'github.com/nixos/nixpkgs\ngithub.com/o/r?dir=sub'
finish

inputs_setup . '["EOF"]'
run_step "flake-lock-inputs: no source ends the list" ok "$ACTIONS/$step" "$step"
expect_lines allow-duplicates "EOF"
finish

for flake in .. ./.. ./ dev /dev "./a b"; do
  inputs_setup "$flake" '[]'
  run_step "flake-lock-inputs: rejects the flake '$flake'" fail "$ACTIONS/$step" "$step"
  expect message "flake must be . or a path below it, not $flake"
  finish
done

for duplicates in '"github.com/nixos/nixpkgs"' '[1]' '[""]' '["a b"]' '["a\nb"]' 'x' ''; do
  inputs_setup . "$duplicates"
  run_step "flake-lock-inputs: rejects allow-duplicates '$duplicates'" fail "$ACTIONS/$step" "$step"
  expect message "allow-duplicates is not a JSON array of sources"
  finish
done

inputs_setup . '["github.com/a/b\n::warning::forged"]'
run_step "flake-lock-inputs: rejects a source that would forge a command" fail "$ACTIONS/$step" "$step"
expect warnings 0
[[ ! -s $work/output ]] || report "unexpected outputs: $(cat "$work/output")"
finish

inputs_setup ./dev '["github.com/nixos/nixpkgs"]'
run_hostile "flake-lock-inputs: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect output path dev/flake.lock
expect_lines allow-duplicates github.com/nixos/nixpkgs
finish
