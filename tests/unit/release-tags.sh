# shellcheck shell=bash
# Tests of release-tags.

step=release-tags
readonly PRESET_RELEASE="repos/flakeyard/renovate-config/releases/tags/v0.1.0"

# tags_setup CONFIG: renovate.json is CONFIG, no Copier answers, and v0.1.0
# of flakeyard/renovate-config is an immutable pre-release.
tags_setup() {
  action_setup
  apply ENABLED=true ALLOW_UNPINNED='[]'
  file_fixture "$REPO" renovate.json "$SHA" "$1"
  listing_fixture "" renovate.json
  fixture "$PRESET_RELEASE" '{"tag_name":"v0.1.0","immutable":true,"prerelease":true}'
}

# answers_setup FILE ANSWERS: the Copier answers FILE at the root.
answers_setup() {
  local file=$1 answers=$2
  listing_fixture "" "$file" .copier-answers.d.yml/
  file_fixture "$REPO" "$file" "$SHA" "$answers"
}

tags_setup '{"extends":["github>flakeyard/renovate-config//internal/workflow#v0.1.0",":semanticCommits","config:recommended"]}'
run_step "release-tags: a preset of an immutable release and built-in presets" ok "$ACTIONS/$step" "$step"
expect summary "| \`preset github>flakeyard/renovate-config//internal/workflow#v0.1.0\` | \`flakeyard/renovate-config v0.1.0\` |"
finish

tags_setup '{"extends":["github>flakeyard/renovate-config#v0.1.0"],"packageRules":[{"extends":["github>flakeyard/renovate-config:x#v0.2.0"]}]}'
run_step "release-tags: every extends is checked" fail "$ACTIONS/$step" "$step"
expect message "preset github>flakeyard/renovate-config:x#v0.2.0: flakeyard/renovate-config has no release v0.2.0 that GITHUB_TOKEN can read"
finish

tags_setup '{"extends":["github>flakeyard/renovate-config#v0.1.0"]}'
fixture "$PRESET_RELEASE" '{"tag_name":"v0.1.0","immutable":false}'
run_step "release-tags: a release that is not immutable" fail "$ACTIONS/$step" "$step"
expect message "the release v0.1.0 of flakeyard/renovate-config is not immutable"
finish

# Presets that are not pinned to a release tag.
for preset in "github>flakeyard/renovate-config" "github>flakeyard/renovate-config#v1" \
  "github>flakeyard/renovate-config#main" "github>flakeyard/renovate-config#v1.2.3-rc.1" \
  "github>flakeyard/renovate-config#v0.1.0/../../x"; do
  tags_setup "$(jq -n --arg preset "$preset" '{extends: [$preset]}')"
  run_step "release-tags: rejects $preset" fail "$ACTIONS/$step" "$step"
  expect message "not pinned to a release tag vX.Y.Z"
  expect no-calls
  finish
done

for preset in "local>flakeyard/renovate-config" "gitlab>a/b#v1.0.0" "https://example.org/p.json" "@acme/renovate-config"; do
  tags_setup "$(jq -n --arg preset "$preset" '{extends: [$preset]}')"
  run_step "release-tags: rejects $preset" fail "$ACTIONS/$step" "$step"
  finish
done

tags_setup '{"extends":["github>../x#v1.0.0"]}'
run_step "release-tags: rejects a hostile repository" fail "$ACTIONS/$step" "$step"
expect message "not a GitHub repository: ../x"
finish

# A repository name of dots only would change the path of the API call.
for repository in "owner/.." "owner/."; do
  tags_setup "$(jq -n --arg preset "github>$repository#v1.0.0" '{extends: [$preset]}')"
  run_step "release-tags: rejects the preset of $repository" fail "$ACTIONS/$step" "$step"
  expect message "not a GitHub repository: $repository"
  finish

  tags_setup '{"extends":[]}'
  answers_setup .copier-answers.yml "$(printf '%s\n' "_commit: v1.0.0" "_src_path: gh:$repository")"
  run_step "release-tags: rejects the template gh:$repository" fail "$ACTIONS/$step" "$step"
  expect message "not a GitHub repository: $repository"
  finish
done

if has_wide_ranges; then
  tags_setup '{"extends":["github>öwner/répo#v1.0.0"]}'
  apply_wide_locale
  run_step "release-tags: rejects a repository beyond ASCII in $WIDE_LOCALE" fail "$ACTIONS/$step" "$step"
  expect message "not a GitHub repository: öwner/répo"
  finish
fi

tags_setup '{"extends":["github>owner/.github#v1.0.0"]}'
fixture "repos/owner/.github/releases/tags/v1.0.0" '{"immutable":true}'
run_step "release-tags: a preset of owner/.github" ok "$ACTIONS/$step" "$step"
finish

tags_setup '{"extends":["github>someone/presets","local>someone/presets"]}'
apply ALLOW_UNPINNED='["SomeOne/presets"]'
run_step "release-tags: allowed sources are not checked" ok "$ACTIONS/$step" "$step"
expect message "::notice::preset github>someone/presets: someone/presets may be unpinned"
finish

tags_setup '{"extends":"github>x/y"}'
run_step "release-tags: rejects an extends that is not a list" fail "$ACTIONS/$step" "$step"
expect message "renovate.json is not JSON whose extends are arrays of one-line strings"
finish

tags_setup '{"extends":["github>x/y#v1.0.0\n::warning::forged"]}'
run_step "release-tags: rejects multi-line presets" fail "$ACTIONS/$step" "$step"
expect warnings 0
finish

tags_setup '{"extends":["github>flakeyard/renovate-config#v0.1.0"]}'
fixture "$PRESET_RELEASE" "HTTP 500"
run_step "release-tags: an API error fails" fail "$ACTIONS/$step" "$step"
expect message "cannot read the release v0.1.0 of flakeyard/renovate-config"
finish

action_setup
apply ENABLED=true ALLOW_UNPINNED='[]'
listing_fixture ""
run_step "release-tags: nothing to check" ok "$ACTIONS/$step" "$step"
finish

# A template pinned to v1.2.0 of flakeyard/template-x, in one of the forms
# Copier writes.
for source in "gh:flakeyard/template-x" "https://github.com/flakeyard/template-x.git" \
  "'https://github.com/flakeyard/template-x'"; do
  tags_setup '{"extends":[]}'
  answers_setup .copier-answers.yml "$(printf '%s\n' "_commit: v1.2.0" "_src_path: $source" "name: x")"
  fixture "repos/flakeyard/template-x/releases/tags/v1.2.0" '{"immutable":true}'
  run_step "release-tags: a template from $source" ok "$ACTIONS/$step" "$step"
  expect summary "\`flakeyard/template-x v1.2.0\`"
  finish
done

tags_setup '{"extends":[]}'
answers_setup .copier-answers.atom.yml $'_commit: v1.2.0-3-gabcdef0\n_src_path: gh:flakeyard/template-x'
run_step "release-tags: a template at a commit after its tag" fail "$ACTIONS/$step" "$step"
expect message "template of .copier-answers.atom.yml: not pinned to a release tag vX.Y.Z"
finish

tags_setup '{"extends":[]}'
answers_setup .copier-answers.yml $'_commit: v1.2.0\n_src_path: gl:acme/template'
run_step "release-tags: a template outside GitHub" fail "$ACTIONS/$step" "$step"
expect message "not a template on GitHub: gl:acme/template"
finish

tags_setup '{"extends":[]}'
answers_setup .copier-answers.yml $'_commit: v1.2.0\n_src_path: gh:flakeyard/template-x'
run_step "release-tags: a template without a release" fail "$ACTIONS/$step" "$step"
expect message "flakeyard/template-x has no release v1.2.0"
finish

action_setup
apply ENABLED=false ALLOW_UNPINNED='[]'
run_step "release-tags: switched off" ok "$ACTIONS/$step" "$step"
expect message "::notice::the release tag check is off"
finish

# More presets that fail than annotations of a kind: the last one counts the
# rest.
tags_setup "$(jq -n '{extends: [range(12) | "github>o/p\(.)"]}')"
run_step "release-tags: the errors beyond the annotations of a step are counted" fail "$ACTIONS/$step" "$step"
expect message "github>o/p8: not pinned"
expect no-message "github>o/p9: not pinned"
expect message "3 more errors are not shown here."
finish

tags_setup '{"extends":[]}'
apply ALLOW_UNPINNED='["../x"]'
run_step "release-tags: rejects allow-unpinned with a hostile entry" fail "$ACTIONS/$step" "$step"
expect no-calls
finish

tags_setup '{"extends":["github>flakeyard/renovate-config#v0.1.0"]}'
run_hostile "release-tags: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect summary "| \`preset github>flakeyard/renovate-config#v0.1.0\` | \`flakeyard/renovate-config v0.1.0\` |"
finish
