# shellcheck shell=bash
# Tests of lib/github/directory.sh.

lib=.github/actions/lib/github/directory.sh

action_setup
listing_fixture "" renovate.json .github/
run_lib "directory: the root" ok "$lib" directory_at "" "$SHA"
expect stdout '[{"name":"renovate.json","type":"file"},{"name":".github","type":"dir"}]'
finish

action_setup
listing_fixture .github workflows/
run_lib "directory: a directory below the root" ok "$lib" directory_at .github "$SHA"
expect stdout '[{"name":"workflows","type":"dir"}]'
finish

# directory_status DIR: print the status of directory_at DIR at SHA.
directory_status() {
  local dir=$1 status=0
  directory_at "$dir" "$SHA" >/dev/null || status=$?
  printf '%s\n' "$status"
}

# The status 3 restates NOT_FOUND of the library as an independent oracle.
action_setup
run_lib "directory: a missing directory is NOT_FOUND" ok "$lib" directory_status .gitlab
expect stdout 3
finish

action_setup
file_fixture "$REPO" .github "$SHA" '{}'
run_lib "directory: a file is not a directory" ok "$lib" directory_status .github
expect stdout 1
expect message ".github: not a directory"
finish
