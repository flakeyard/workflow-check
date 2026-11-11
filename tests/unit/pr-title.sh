# shellcheck shell=bash
# Tests of pr-title.

script=.github/actions/pr-title/run.sh
readonly DEFAULT_TYPES="feat fix docs chore ci refactor test build perf revert"
branch_pulls="repos/o/r/pulls?state=open&head=o%3Arelease-please--branches--main&per_page=100"

# title_setup TITLE: a pull_request run of pull request 5 with TITLE.
title_setup() {
  action_setup
  apply EVENT=pull_request NUMBER=5 ENABLED=true TYPES="$DEFAULT_TYPES"
  fixture "repos/$REPO/pulls/5" "$(jq -n --arg title "$1" '{number: 5, title: $title}')"
}

# Titles that follow the rule.
for title in "feat: add a check" "fix(pr-title): accept scopes" "feat!: drop an input" \
  "chore(release/v1): release 1.2.1" "revert(a.b_c-d): undo it"; do
  title_setup "$title"
  run "pr-title: accepts '$title'" ok "$script"
  expect summary "pull request #5: \`$title\`"
  finish
done

# Titles that do not.
for title in "Add a check" "feature: add" "feat:add" "feat:  add" "feat(Scope): add" \
  "feat(): add" "Feat: add" "feat :add" "featx: add" "feat(a)(b): add" "feat: " \
  "chore(méin): release 0.2.0"; do
  title_setup "$title"
  run "pr-title: rejects '$title'" fail "$script"
  expect message "pull request #5: the title"
  finish
done

if has_wide_ranges; then
  title_setup "chore(méin): release 0.2.0"
  apply_wide_locale
  run "pr-title: rejects a scope beyond ASCII in $WIDE_LOCALE" fail "$script"
  expect message "pull request #5: the title"
  finish
fi

title_setup $'feat: one\n::warning::forged'
run "pr-title: a title cannot forge a command" fail "$script"
expect warnings 0
finish

title_setup "docs: explain"
apply TYPES="feat fix"
run "pr-title: only the given types" fail "$script"
expect message "with a type of: feat fix"
finish

for types in "" "feat|.*" "feat  fix" "Feat" "feat " "a.*"; do
  title_setup "feat: add"
  apply TYPES="$types"
  run "pr-title: rejects the types '$types'" fail "$script"
  expect message "pr-title-types must be lower-case words"
  expect no-calls
  finish
done

title_setup "Add a check"
apply ENABLED=false
run "pr-title: switched off" ok "$script"
expect message "::notice::the pull request title check is off"
finish

for event in push schedule; do
  action_setup
  apply EVENT="$event" ENABLED=true TYPES="$DEFAULT_TYPES"
  run "pr-title: nothing to check on $event" ok "$script"
  expect message "::notice::not a pull request"
  finish
done

title_setup "feat: add"
apply NUMBER="5/../6"
run "pr-title: rejects a pull request number that is not one" fail "$script"
finish

action_setup
apply EVENT=pull_request NUMBER=5 ENABLED=true TYPES="$DEFAULT_TYPES"
fixture "repos/$REPO/pulls/5" "HTTP 500"
run "pr-title: an API error fails" fail "$script"
finish

# dispatch_setup PULLS: a dispatched run of the release branch, whose open
# pull requests are PULLS.
dispatch_setup() {
  action_setup
  apply EVENT=workflow_dispatch OWNER=o BRANCH=release-please--branches--main \
    ENABLED=true TYPES="$DEFAULT_TYPES"
  fixture "$branch_pulls" "$1"
}

dispatch_setup '[{"number":7,"title":"chore(main): release 0.2.0"}]'
run "pr-title: a dispatched run checks the pull request of its branch" ok "$script"
expect summary "pull request #7"
finish

# More bad titles than annotations of a kind: the last one counts the rest.
dispatch_setup "$(jq -n '[range(1; 12) | {number: ., title: "bad"}]')"
run "pr-title: the errors beyond the annotations of a step are counted" fail "$script"
expect message "pull request #9: the title"
expect no-message "pull request #10: the title"
expect message "2 more errors are not shown here."
finish

dispatch_setup '[{"number":7,"title":"chore(main): release 0.2.0"},{"number":8,"title":"Release"}]'
run "pr-title: a dispatched run checks every pull request of its branch" fail "$script"
expect message "pull request #8: the title"
expect no-message "pull request #7: the title"
finish

# The delay restates _API_RETRY_DELAY of the library as an independent oracle.
dispatch_setup '[{"number":7,"title":"chore(main): release 0.2.0"}]'
transient_failures "$branch_pulls" 1
run "pr-title: a transient error of the pull requests of the branch is retried" ok "$script"
expect sleeps 5
expect summary "pull request #7"
finish

dispatch_setup '[]'
transient_failures "$branch_pulls" 3
run "pr-title: an error of the pull requests of the branch that lasts fails" fail "$script"
expect message "cannot list the pull requests of release-please--branches--main"
finish

dispatch_setup '[]'
run "pr-title: a dispatched branch without pull requests" ok "$script"
expect message "::notice::no open pull request of release-please--branches--main"
finish

dispatch_setup '[]'
apply BRANCH="a&b#c"
fixture "repos/o/r/pulls?state=open&head=o%3Aa%26b%23c&per_page=100" '[{"number":9,"title":"fix: x"}]'
run "pr-title: the branch is encoded in the query" ok "$script"
expect summary "pull request #9"
finish
