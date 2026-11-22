#!/usr/bin/env bash
# Fails unless pull request titles follow Conventional Commits with the types
# in TYPES: on pull_request the title of pull request NUMBER, on merge_group
# that of the queued pull request named by HEAD_REF, the queue branch, and on
# workflow_dispatch those of every open pull request of BRANCH. Titles are read
# from the API, so a rerun after the title was fixed passes, and a title edited
# in the merge queue is checked before the squash commit takes it. Other events
# have no pull request; ENABLED=false switches the check off.
set -euo pipefail
: "${SHELL_LIB:?}" "${REPO:?}" "${EVENT?}" "${ENABLED:?}" "${TYPES?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "${SHELL_LIB}/env.sh"
step_environment
# shellcheck source=/dev/null
source "${SHELL_LIB}/github/api.sh"
# shellcheck source=/dev/null
source "${SHELL_LIB}/report.sh"

readonly TYPES_FORM='^[a-z]+( [a-z]+)*$'
readonly NUMBER_FORM='^[1-9][0-9]*$'
# The ref of a merge queue branch; the group holds pull request N.
readonly QUEUE_REF_FORM='^refs/heads/gh-readonly-queue/[^[:space:]]+/pr-([1-9][0-9]*)-[0-9a-f]{40}$'
# Conventional Commits after the type: an optional scope, an optional "!" and
# a description that starts with a character other than a space.
readonly AFTER_TYPE='(\([a-z0-9._/-]+\))?!?: [^[:space:]].*$'

# title_rule: print the rule for titles with the types of TYPES.
title_rule() {
  printf '^(%s)%s\n' "${TYPES// /|}" "${AFTER_TYPE}"
}

# check_title NUMBER TITLE: report whether pull request NUMBER has a title
# that follows the rule, on one line; a problem when it does not.
check_title() {
  local number=$1 title=$2 span
  if [[ ${title} != *[$'\n\r']* && ${title} =~ ${rule} ]]; then
    span=$(code_span "${title}")
    summary "pull request #${number}: ${span}"
  else
    problem "pull request #${number}: the title \"${title}\" does not follow Conventional Commits, <type>[(<scope>)][!]: <description> with a type of: ${TYPES}"
  fi
}

# check_pull_request NUMBER: check the title of pull request NUMBER.
check_pull_request() {
  local number=$1 pull title
  [[ ${number} =~ ${NUMBER_FORM} ]] || fail "not a pull request number: ${number}"
  pull=$(api_get "repos/${REPO}/pulls/${number}") || fail "cannot read pull request #${number}"
  title=$(jq -r .title <<<"${pull}")
  check_title "${number}" "${title}"
}

# check_merge_group: check the title of the pull request of the merge queue
# branch HEAD_REF.
check_merge_group() {
  [[ ${HEAD_REF:-} =~ ${QUEUE_REF_FORM} ]] \
    || fail "not a merge queue branch of the form refs/heads/gh-readonly-queue/<base>/pr-<number>-<sha>: \"${HEAD_REF:-}\""
  check_pull_request "${BASH_REMATCH[1]}"
}

# check_branch: check the titles of the open pull requests of BRANCH;
# transient errors of the API are retried.
check_branch() {
  local head pulls pull number title
  head=$(jq -rn --arg head "${OWNER}:${BRANCH}" '$head | @uri')
  pulls=$(api_request GET "repos/${REPO}/pulls?state=open&head=${head}&per_page=100" \
    --paginate --jq '.[] | {number, title} | @json') || fail "cannot list the pull requests of ${BRANCH}"
  if [[ -z ${pulls} ]]; then
    notice "no open pull request of ${BRANCH}; no title to check"
    return 0
  fi
  while IFS= read -r pull; do
    number=$(jq -r .number <<<"${pull}")
    title=$(jq -r .title <<<"${pull}")
    check_title "${number}" "${title}"
  done <<<"${pulls}"
}

if [[ ${ENABLED} != true ]]; then
  notice "the pull request title check is off"
  exit 0
fi
[[ ${TYPES} =~ ${TYPES_FORM} ]] || fail "pr-title-types must be lower-case words separated by single spaces, not \"${TYPES}\""
rule=$(title_rule)
case ${EVENT} in
  pull_request) check_pull_request "${NUMBER:-}" ;;
  merge_group) check_merge_group ;;
  workflow_dispatch) check_branch ;;
  *) notice "not a pull request; no title to check" ;;
esac
flush
! has_problems
