#!/usr/bin/env bash
# Fails unless pull request titles follow Conventional Commits with the types
# in TYPES: on pull_request the title of pull request NUMBER, on
# workflow_dispatch those of every open pull request of BRANCH. Titles are read
# from the API, so a rerun after the title was fixed passes. Other events have
# no pull request; ENABLED=false switches the check off.
set -euo pipefail
shopt -s inherit_errexit
# Ranges such as [a-z] match only ASCII, whatever the locale of the runner.
export LC_ALL=C.UTF-8
: "${SHELL_LIB:?}" "${REPO:?}" "${EVENT?}" "${ENABLED:?}" "${TYPES?}"
# shellcheck source=/dev/null
source "$SHELL_LIB/github/api.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"

readonly TYPES_FORM='^[a-z]+( [a-z]+)*$'
readonly NUMBER_FORM='^[1-9][0-9]*$'
# Conventional Commits after the type: an optional scope, an optional "!" and
# a description that starts with a character other than a space.
readonly AFTER_TYPE='(\([a-z0-9._/-]+\))?!?: [^[:space:]].*$'

# title_rule: print the rule for titles with the types of TYPES.
title_rule() {
  printf '^(%s)%s\n' "${TYPES// /|}" "$AFTER_TYPE"
}

# is_single_line TEXT: TEXT has no line break.
is_single_line() {
  [[ $1 != *[$'\n\r']* ]]
}

# check_title NUMBER TITLE: report whether pull request NUMBER has a title
# that follows the rule; a problem when it does not.
check_title() {
  local number=$1 title=$2
  if is_single_line "$title" && [[ $title =~ $rule ]]; then
    summary "pull request #$number: $(code_span "$title")"
  else
    problem "pull request #$number: the title \"$title\" does not follow Conventional Commits, <type>[(<scope>)][!]: <description> with a type of: $TYPES"
  fi
}

# check_pull_request NUMBER: check the title of pull request NUMBER.
check_pull_request() {
  local number=$1 pull
  [[ $number =~ $NUMBER_FORM ]] || fail "not a pull request number: $number"
  pull=$(api_get "repos/$REPO/pulls/$number") || fail "cannot read pull request #$number"
  check_title "$number" "$(jq -r .title <<<"$pull")"
}

# check_branch: check the titles of the open pull requests of BRANCH;
# transient errors of the API are retried.
check_branch() {
  local head pulls pull
  head=$(jq -rn --arg head "$OWNER:$BRANCH" '$head | @uri')
  pulls=$(api_request GET "repos/$REPO/pulls?state=open&head=$head&per_page=100" \
    --paginate --jq '.[] | {number, title} | @json') || fail "cannot list the pull requests of $BRANCH"
  if [[ -z $pulls ]]; then
    notice "no open pull request of $BRANCH; no title to check"
    return 0
  fi
  while IFS= read -r pull; do
    check_title "$(jq -r .number <<<"$pull")" "$(jq -r .title <<<"$pull")"
  done <<<"$pulls"
}

if [[ $ENABLED != true ]]; then
  notice "the pull request title check is off"
  exit 0
fi
[[ $TYPES =~ $TYPES_FORM ]] || fail "pr-title-types must be lower-case words separated by single spaces, not \"$TYPES\""
rule=$(title_rule)
case $EVENT in
  pull_request) check_pull_request "${NUMBER:-}" ;;
  workflow_dispatch) check_branch ;;
  *) notice "not a pull request; no title to check" ;;
esac
flush
! has_problems
