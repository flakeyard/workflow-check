# shellcheck shell=bash
# Tests of lib/outputs.sh, with the stub of nix.
# shellcheck disable=SC2016 # Code for eval, not expansions.

lib=.github/actions/lib/outputs.sh

# with_report FUNCTION [ARG...]: run FUNCTION with report.sh of the library,
# as the scripts that source outputs.sh do.
with_report() {
  # shellcheck source=/dev/null
  source "${SHELL_LIB}/report.sh"
  "$@"
}

# names_of FLAKE SYSTEM OUTPUT EXPECTED [OPTION...]: print the names that
# output_names sets, one per line, with the nix of the PATH.
# shellcheck disable=SC2034,SC2154 # nix is read and names set by output_names.
names_of() {
  nix=nix
  with_report output_names "$@"
  printf '%s\n' "${names[@]}"
}

for system in x86_64-linux aarch64-linux; do
  action_setup
  run_lib "outputs: ${system} is a system" ok "${lib}" with_report check_system "${system}"
  finish
done

for system in "" x86_64 "x86_64-linux; y" X86_64-linux "x86_64-linux
" "-linux"; do
  action_setup
  run_lib "outputs: '${system}' is no system" fail "${lib}" with_report check_system "${system}"
  expect message "::error::not a system"
  finish
done

for list in '[]' '["a"]' '["a","b.c","_x","a+b","a-1"]'; do
  action_setup
  run_lib "outputs: ${list} is a list of names" ok "${lib}" is_name_list "${list}"
  finish
done

for list in '' 'null' '"a"' '{}' '[1]' '[""]' '["-a"]' '[".a"]' '["+a"]' '["a b"]' '["a\"b"]' '["a\n"]' \
  '["é"]' 'not json'; do
  action_setup
  run_lib "outputs: '${list}' is no list of names" fail "${lib}" is_name_list "${list}"
  finish
done

action_setup
run_lib "outputs: read_names keeps the order and is empty for []" ok "${lib}" \
  eval 'read_names a "[\"b.c\",\"a\"]"; read_names e "[]"; printf "%s|" "${a[@]}" "${#e[@]}"'
expect stdout 'b.c|a|0|'
finish

action_setup
apply NIX_APPS='["a","b.c"]'
run_lib "outputs: the names of an output" ok "${lib}" names_of ./dev x86_64-linux apps '["b.c"]' \
  --no-update-lock-file
expect stdout $'a\nb.c'
finish

# The missing names in the order of EXPECTED, as given.
action_setup
apply NIX_APPS='["a"]'
run_lib "outputs: missing names fail" fail "${lib}" names_of ./dev x86_64-linux apps '["z","a","b"]' \
  --no-update-lock-file
expect message "::error::the flake ./dev has no apps.x86_64-linux of: z, b"
finish

action_setup
apply NIX_APPS='["a\"; b"]'
run_lib "outputs: names out of form fail" fail "${lib}" names_of . x86_64-linux apps '[]' --no-update-lock-file
expect message "::error::the names of apps.x86_64-linux must match"
finish

action_setup
apply NIX_APPS='["a"]' NIX_EVAL_ERROR="attribute missing"
run_lib "outputs: a flake that does not evaluate fails" fail "${lib}" names_of . x86_64-linux apps '[]' \
  --no-update-lock-file
expect message "::error::cannot evaluate the apps of the flake ."
finish

action_setup
apply NIX_APPS='[]'
run_lib "outputs: the options reach nix" fail "${lib}" names_of . x86_64-linux apps '[]'
expect message "without --no-update-lock-file"
finish
