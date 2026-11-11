# shellcheck shell=bash
# Directories of the repository REPO at a commit, read through the contents
# API: one request lists a directory, where a request per file would ask for
# each name. Source this file; it expects REPO and SHELL_LIB, the directory
# of the shell library.

# shellcheck source=/dev/null
source "$SHELL_LIB/github/api.sh"

# The root of the repository, as DIR of directory_at.
readonly ROOT_DIR=""

# directory_path DIR REF: print the API path of the directory DIR of REPO at
# REF; ROOT_DIR is the root.
directory_path() {
  local dir=$1 ref=$2
  if [[ $dir == "$ROOT_DIR" ]]; then
    printf 'repos/%s/contents?ref=%s\n' "$REPO" "$ref"
  else
    printf 'repos/%s/contents/%s?ref=%s\n' "$REPO" "$dir" "$ref"
  fi
}

# directory_at DIR REF: print the entries of the directory DIR of REPO, at
# the commit REF, as a JSON array of {name, type}, with the type file, dir,
# symlink or submodule; ROOT_DIR is the root. DIR is a path that needs no
# encoding, such as .github. Returns 0 on success, NOT_FOUND when DIR does not
# exist and 1 on any other error, such as a DIR that is a file, after printing
# it on stderr. The API lists at most 1,000 entries of a directory; a larger
# one would need the Git trees API.
directory_at() {
  local dir=$1 ref=$2 body status=0
  body=$(api_request GET "$(directory_path "$dir" "$ref")") || status=$?
  ((status == 0)) || return "$status"
  jq -ce 'arrays | map({name, type})' <<<"$body" 2>/dev/null || {
    printf '%s: not a directory\n' "${dir:-the root}" >&2
    return 1
  }
}
