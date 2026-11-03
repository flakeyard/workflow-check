# shellcheck shell=bash
# Tests of scripts/check/eol.sh.
# shellcheck disable=SC2154 # work is the directory of the test, from setup.
# shellcheck disable=SC2034 # current is the test that report and finish count.

: "${root:?}"

script=check/eol.sh

# eol_setup CONTENT: an EOL file with CONTENT, given to printf %b.
eol_setup() {
  setup
  eol_file=$work/eol
  printf '%b' "$1" >"$eol_file"
}

for case in "2026-10-29 ok supported" "2026-12-10 ok in 21 days" "2027-01-02 fail reached its end of life"; do
  read -r today expected message <<<"$case"
  eol_setup '# comment\nnixos-26.05 2026-12-31\n'
  run_script "eol: $today" "$expected" "$script" "$eol_file" "$today"
  expect message "$message"
  finish
done

# A malformed EOL file fails with a message instead of counting from today.
while IFS='|' read -r name content message; do
  eol_setup "$content"
  run_script "eol: $name" fail "$script" "$eol_file" 2026-10-29
  expect message "$message"
  finish
done <<'CASES'
no date|# comment\nnixos-26.05\n|'' is not a date
an invalid date|nixos-26.05 2026-02-30\n|'2026-02-30' is not a date
another date format|nixos-26.05 31.12.2026\n|'31.12.2026' is not a date
no data line|# comment\n\n|no data line
an empty file||no data line
two data lines|nixos-26.05 2026-12-31\nnixos-26.11 2027-06-30\n|more than one data line
not a branch|2026-12-31\n|'2026-12-31' is not a branch
an extra field|nixos-26.05 2026-12-31 x\n|unexpected 'x'
CASES

eol_setup 'nixos-26.05 2026-12-31'
run_script "eol: a last line without a newline" ok "$script" "$eol_file" 2026-10-29
expect message "supported until 2026-12-31"
finish

eol_setup 'nixos-26.05 2026-12-31\n'
run_script "eol: an invalid today" fail "$script" "$eol_file" ""
expect message "'' is not a date"
finish

setup
run_script "eol: a missing file" fail "$script" "$work/none"
finish

# The EOL file of this repository names the branch of nixpkgs in flake.lock.
setup
current="eol: nixpkgs-eol names the branch of flake.lock"
read -r branch _ < <(grep -v '^#' "$root/nixpkgs-eol")
jq -e --arg branch "$branch" '.nodes.nixpkgs.original.ref == $branch' "$root/flake.lock" >/dev/null \
  || report "nixpkgs-eol names $branch, flake.lock follows another branch"
finish
