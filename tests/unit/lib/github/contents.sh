# shellcheck shell=bash
# Tests of lib/github/contents.sh.

lib=github/contents.sh

setup
file_fixture a.json $'{\n  "a": 1\n}\n'
run_lib "contents: a file is decoded" ok "$lib" file_at a.json "$SHA"
expect stdout $'{\n  "a": 1\n}'
finish

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
