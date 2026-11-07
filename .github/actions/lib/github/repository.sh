# shellcheck shell=bash
# Names of GitHub repositories, as the actions read them from files and inputs.

# owner/repo as GitHub allows them. A repository name needs a character other
# than a dot: ".." or "." would change the path of an API call.
readonly REPOSITORY_FORM='^[A-Za-z0-9-]+/[A-Za-z0-9._-]*[A-Za-z0-9_-][A-Za-z0-9._-]*$'

# is_repository_list JSON: JSON is an array of owner/repo.
is_repository_list() {
  local list=$1
  jq -e --arg form "$REPOSITORY_FORM" \
    'type == "array" and all(.[]; type == "string" and test($form))' \
    <<<"$list" >/dev/null 2>&1
}

# lists_repository LIST REPOSITORY: the JSON array LIST has REPOSITORY,
# compared without case as GitHub does.
lists_repository() {
  local list=$1 repository=$2
  jq -e --arg repository "$repository" \
    'any(.[]; ascii_downcase == ($repository | ascii_downcase))' \
    <<<"$list" >/dev/null
}
