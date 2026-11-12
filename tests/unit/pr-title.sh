# shellcheck shell=bash
# Tests of pr-title.

step=pr-title
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
  run_step "pr-title: accepts '$title'" ok "$ACTIONS/$step" "$step"
  expect summary "pull request #5: \`$title\`"
  finish
done

# Titles that do not.
for title in "Add a check" "feature: add" "feat:add" "feat:  add" "feat(Scope): add" \
  "feat(): add" "Feat: add" "feat :add" "featx: add" "feat(a)(b): add" "feat: " \
  "chore(méin): release 0.2.0"; do
  title_setup "$title"
  run_step "pr-title: rejects '$title'" fail "$ACTIONS/$step" "$step"
  expect message "pull request #5: the title"
  finish
done

if has_wide_ranges; then
  title_setup "chore(méin): release 0.2.0"
  apply_wide_locale
  run_step "pr-title: rejects a scope beyond ASCII in $WIDE_LOCALE" fail "$ACTIONS/$step" "$step"
  expect message "pull request #5: the title"
  finish
fi

title_setup $'feat: one\n::warning::forged'
run_step "pr-title: a title cannot forge a command" fail "$ACTIONS/$step" "$step"
expect warnings 0
finish

title_setup "docs: explain"
apply TYPES="feat fix"
run_step "pr-title: only the given types" fail "$ACTIONS/$step" "$step"
expect message "with a type of: feat fix"
finish

for types in "" "feat|.*" "feat  fix" "Feat" "feat " "a.*"; do
  title_setup "feat: add"
  apply TYPES="$types"
  run_step "pr-title: rejects the types '$types'" fail "$ACTIONS/$step" "$step"
  expect message "pr-title-types must be lower-case words"
  expect no-calls
  finish
done

title_setup "Add a check"
apply ENABLED=false
run_step "pr-title: switched off" ok "$ACTIONS/$step" "$step"
expect message "::notice::the pull request title check is off"
finish

for event in push schedule; do
  action_setup
  apply EVENT="$event" ENABLED=true TYPES="$DEFAULT_TYPES"
  run_step "pr-title: nothing to check on $event" ok "$ACTIONS/$step" "$step"
  expect message "::notice::not a pull request"
  finish
done

title_setup "feat: add"
apply NUMBER="5/../6"
run_step "pr-title: rejects a pull request number that is not one" fail "$ACTIONS/$step" "$step"
finish

action_setup
apply EVENT=pull_request NUMBER=5 ENABLED=true TYPES="$DEFAULT_TYPES"
fixture "repos/$REPO/pulls/5" "HTTP 500"
run_step "pr-title: an API error fails" fail "$ACTIONS/$step" "$step"
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
run_step "pr-title: a dispatched run checks the pull request of its branch" ok "$ACTIONS/$step" "$step"
expect summary "pull request #7"
finish

# More bad titles than annotations of a kind: the last one counts the rest.
dispatch_setup "$(jq -n '[range(1; 12) | {number: ., title: "bad"}]')"
run_step "pr-title: the errors beyond the annotations of a step are counted" fail "$ACTIONS/$step" "$step"
expect message "pull request #9: the title"
expect no-message "pull request #10: the title"
expect message "2 more errors are not shown here."
finish

dispatch_setup '[{"number":7,"title":"chore(main): release 0.2.0"},{"number":8,"title":"Release"}]'
run_step "pr-title: a dispatched run checks every pull request of its branch" fail "$ACTIONS/$step" "$step"
expect message "pull request #8: the title"
expect no-message "pull request #7: the title"
finish

# The delay restates _API_RETRY_DELAY of the library as an independent oracle.
dispatch_setup '[{"number":7,"title":"chore(main): release 0.2.0"}]'
transient_failures "$branch_pulls" 1
run_step "pr-title: a transient error of the pull requests of the branch is retried" ok "$ACTIONS/$step" "$step"
expect sleeps 5
expect summary "pull request #7"
finish

dispatch_setup '[]'
transient_failures "$branch_pulls" 3
run_step "pr-title: an error of the pull requests of the branch that lasts fails" fail "$ACTIONS/$step" "$step"
expect message "cannot list the pull requests of release-please--branches--main"
finish

dispatch_setup '[]'
run_step "pr-title: a dispatched branch without pull requests" ok "$ACTIONS/$step" "$step"
expect message "::notice::no open pull request of release-please--branches--main"
finish

dispatch_setup '[]'
apply BRANCH="a&b#c"
fixture "repos/o/r/pulls?state=open&head=o%3Aa%26b%23c&per_page=100" '[{"number":9,"title":"fix: x"}]'
run_step "pr-title: the branch is encoded in the query" ok "$ACTIONS/$step" "$step"
expect summary "pull request #9"
finish

title_setup "feat: add a check"
run_hostile "pr-title: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect summary "pull request #5: \`feat: add a check\`"
finish
