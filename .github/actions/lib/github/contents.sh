# shellcheck shell=bash source-path=SCRIPTDIR
# Files of REPO at a commit, read through the contents API. Source this file;
# it expects REPO.

# shellcheck source=api.sh
source "${BASH_SOURCE[0]%/*}/api.sh"

# api_path PATH: PATH with every segment percent-encoded, such as "#" or "?"
# of a file name, and the "/" between them kept.
api_path() {
  jq -rn --arg path "$1" '$path | split("/") | map(@uri) | join("/")'
}

# file_at PATH REF: print a file of the repository at commit REF. Returns 0 on
# success, NOT_FOUND when the file does not exist and 1 on any other error,
# such as a directory or a file too large for the API.
file_at() {
  local path=$1 ref=$2 body status=0
  body=$(api_request GET "repos/$REPO/contents/$(api_path "$path")?ref=$ref") || status=$?
  ((status == 0)) || return "$status"
  jq -e '.type == "file" and .encoding == "base64"' <<<"$body" >/dev/null || {
    echo "$path: not a file of at most 1 MB" >&2
    return 1
  }
  jq -r .content <<<"$body" | base64 -d
}

# root_files REF: print the names of the files at the root of the repository
# at commit REF, one per line.
root_files() {
  local ref=$1 listing
  listing=$(api_get "repos/$REPO/contents?ref=$ref") || return 1
  jq -r '.[] | select(.type == "file") | .name' <<<"$listing"
}
