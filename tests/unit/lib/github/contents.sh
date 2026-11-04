# shellcheck shell=bash
# Tests of lib/github/contents.sh.

lib=github/contents.sh

setup
file_fixture a.json $'{\n  "a": 1\n}\n'
run_lib "contents: a file is decoded" ok "$lib" file_at a.json "$SHA"
expect stdout $'{\n  "a": 1\n}'
finish

# File names that are not a path of a URL as they are.
while IFS='|' read -r name encoded; do
  setup
  file_fixture "$encoded" "x"
  run_lib "contents: the name '$name' is encoded" ok "$lib" file_at "$name" "$SHA"
  expect stdout "x"
  finish
done <<'CASES'
.copier-answers#x.yml|.copier-answers%23x.yml
.copier-answers?x.yml|.copier-answers%3Fx.yml
.copier answers.yml|.copier%20answers.yml
.github/renovate.json|.github/renovate.json
CASES

# missing_is_not_found: file_at returns NOT_FOUND for a missing file.
missing_is_not_found() {
  local status=0
  file_at a.json "$SHA" || status=$?
  ((status == NOT_FOUND))
}

setup
run_lib "contents: a missing file is NOT_FOUND" ok "$lib" missing_is_not_found
finish

setup
fixture "repos/$REPO/contents?ref=$SHA" '[{"type":"file","name":".copier-answers.yml"},{"type":"dir","name":"nix"}]'
run_lib "contents: the files at the root" ok "$lib" root_files "$SHA"
expect stdout ".copier-answers.yml"
finish
