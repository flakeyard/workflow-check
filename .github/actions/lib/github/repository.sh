# shellcheck shell=bash
# Names of GitHub repositories, as the actions read them from files and inputs.

# owner/repo as GitHub allows them. A repository name needs a character other
# than a dot: ".." or "." would change the path of an API call.
# shellcheck disable=SC2034 # Used by the scripts that source this file.
readonly REPOSITORY_FORM='^[A-Za-z0-9-]+/[A-Za-z0-9._-]*[A-Za-z0-9_-][A-Za-z0-9._-]*$'
