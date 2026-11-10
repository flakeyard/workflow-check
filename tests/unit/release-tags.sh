# shellcheck shell=bash
# Tests of release-tags.

script=release-tags/run.sh
readonly PRESET_RELEASE="repos/flakeyard/renovate-config/releases/tags/v0.1.0"

# tags_setup CONFIG: renovate.json is CONFIG, no Copier answers, and v0.1.0
# of flakeyard/renovate-config is an immutable pre-release.
tags_setup() {
  setup
  apply ENABLED=true ALLOW_UNPINNED='[]'
  file_fixture renovate.json "$1"
  fixture "repos/$REPO/contents?ref=$SHA" '[{"type":"file","name":"renovate.json"}]'
  fixture "$PRESET_RELEASE" '{"tag_name":"v0.1.0","immutable":true,"prerelease":true}'
}

# answers_setup FILE ANSWERS: the Copier answers FILE at the root.
answers_setup() {
  local file=$1 answers=$2
  fixture "repos/$REPO/contents?ref=$SHA" \
    "$(jq -n --arg file "$file" '[{type: "file", name: $file}, {type: "dir", name: ".copier-answers.d.yml"}]')"
  file_fixture "$file" "$answers"
}

tags_setup '{"extends":["github>flakeyard/renovate-config//internal/workflow#v0.1.0",":semanticCommits","config:recommended"]}'
run "release-tags: a preset of an immutable release and built-in presets" ok "$script"
expect summary "| \`preset github>flakeyard/renovate-config//internal/workflow#v0.1.0\` | \`flakeyard/renovate-config v0.1.0\` |"
finish

tags_setup '{"extends":["github>flakeyard/renovate-config#v0.1.0"],"packageRules":[{"extends":["github>flakeyard/renovate-config:x#v0.2.0"]}]}'
run "release-tags: every extends is checked" fail "$script"
expect message "preset github>flakeyard/renovate-config:x#v0.2.0: flakeyard/renovate-config has no release v0.2.0 that GITHUB_TOKEN can read"
finish

tags_setup '{"extends":["github>flakeyard/renovate-config#v0.1.0"]}'
fixture "$PRESET_RELEASE" '{"tag_name":"v0.1.0","immutable":false}'
run "release-tags: a release that is not immutable" fail "$script"
expect message "the release v0.1.0 of flakeyard/renovate-config is not immutable"
finish

# Presets that are not pinned to a release tag.
for preset in "github>flakeyard/renovate-config" "github>flakeyard/renovate-config#v1" \
  "github>flakeyard/renovate-config#main" "github>flakeyard/renovate-config#v1.2.3-rc.1" \
  "github>flakeyard/renovate-config#v0.1.0/../../x"; do
  tags_setup "$(jq -n --arg preset "$preset" '{extends: [$preset]}')"
  run "release-tags: rejects $preset" fail "$script"
  expect message "not pinned to a release tag vX.Y.Z"
  expect no-calls
  finish
done

for preset in "local>flakeyard/renovate-config" "gitlab>a/b#v1.0.0" "https://example.org/p.json" "@acme/renovate-config"; do
  tags_setup "$(jq -n --arg preset "$preset" '{extends: [$preset]}')"
  run "release-tags: rejects $preset" fail "$script"
  finish
done

tags_setup '{"extends":["github>../x#v1.0.0"]}'
run "release-tags: rejects a hostile repository" fail "$script"
expect message "not a GitHub repository: ../x"
finish

# A repository name of dots only would change the path of the API call.
for repository in "owner/.." "owner/."; do
  tags_setup "$(jq -n --arg preset "github>$repository#v1.0.0" '{extends: [$preset]}')"
  run "release-tags: rejects the preset of $repository" fail "$script"
  expect message "not a GitHub repository: $repository"
  finish

  tags_setup '{"extends":[]}'
  answers_setup .copier-answers.yml "$(printf '%s\n' "_commit: v1.0.0" "_src_path: gh:$repository")"
  run "release-tags: rejects the template gh:$repository" fail "$script"
  expect message "not a GitHub repository: $repository"
  finish
done

if has_wide_ranges; then
  tags_setup '{"extends":["github>öwner/répo#v1.0.0"]}'
  apply LC_ALL="$WIDE_LOCALE"
  run "release-tags: rejects a repository beyond ASCII in $WIDE_LOCALE" fail "$script"
  expect message "not a GitHub repository: öwner/répo"
  finish
fi

tags_setup '{"extends":["github>owner/.github#v1.0.0"]}'
fixture "repos/owner/.github/releases/tags/v1.0.0" '{"immutable":true}'
run "release-tags: a preset of owner/.github" ok "$script"
finish

tags_setup '{"extends":["github>someone/presets","local>someone/presets"]}'
apply ALLOW_UNPINNED='["SomeOne/presets"]'
run "release-tags: allowed sources are not checked" ok "$script"
expect message "::notice::preset github>someone/presets: someone/presets may be unpinned"
finish

tags_setup '{"extends":"github>x/y"}'
run "release-tags: rejects an extends that is not a list" fail "$script"
expect message "renovate.json is not JSON whose extends are arrays of one-line strings"
finish

tags_setup '{"extends":["github>x/y#v1.0.0\n::warning::forged"]}'
run "release-tags: rejects multi-line presets" fail "$script"
expect no-command warning
finish

tags_setup '{"extends":["github>flakeyard/renovate-config#v0.1.0"]}'
fixture "$PRESET_RELEASE" "HTTP 500"
run "release-tags: an API error fails" fail "$script"
expect message "cannot read the release v0.1.0 of flakeyard/renovate-config"
finish

setup
apply ENABLED=true ALLOW_UNPINNED='[]'
fixture "repos/$REPO/contents?ref=$SHA" '[]'
run "release-tags: nothing to check" ok "$script"
finish

# A template pinned to v1.2.0 of flakeyard/template-x, in one of the forms
# Copier writes.
for source in "gh:flakeyard/template-x" "https://github.com/flakeyard/template-x.git" \
  "'https://github.com/flakeyard/template-x'"; do
  tags_setup '{"extends":[]}'
  answers_setup .copier-answers.yml "$(printf '%s\n' "_commit: v1.2.0" "_src_path: $source" "name: x")"
  fixture "repos/flakeyard/template-x/releases/tags/v1.2.0" '{"immutable":true}'
  run "release-tags: a template from $source" ok "$script"
  expect summary "\`flakeyard/template-x v1.2.0\`"
  finish
done

tags_setup '{"extends":[]}'
answers_setup .copier-answers.atom.yml $'_commit: v1.2.0-3-gabcdef0\n_src_path: gh:flakeyard/template-x'
run "release-tags: a template at a commit after its tag" fail "$script"
expect message "template of .copier-answers.atom.yml: not pinned to a release tag vX.Y.Z"
finish

tags_setup '{"extends":[]}'
answers_setup .copier-answers.yml $'_commit: v1.2.0\n_src_path: gl:acme/template'
run "release-tags: a template outside GitHub" fail "$script"
expect message "not a template on GitHub: gl:acme/template"
finish

tags_setup '{"extends":[]}'
answers_setup .copier-answers.yml $'_commit: v1.2.0\n_src_path: gh:flakeyard/template-x'
run "release-tags: a template without a release" fail "$script"
expect message "flakeyard/template-x has no release v1.2.0"
finish

setup
apply ENABLED=false ALLOW_UNPINNED='[]'
run "release-tags: switched off" ok "$script"
expect message "::notice::the release tag check is off"
finish

# More presets that fail than annotations of a kind: the last one counts the
# rest.
tags_setup "$(jq -n '{extends: [range(12) | "github>o/p\(.)"]}')"
run "release-tags: the errors beyond the annotations of a step are counted" fail "$script"
expect message "github>o/p8: not pinned"
expect no-message "github>o/p9: not pinned"
expect message "3 more errors are not shown here."
finish

tags_setup '{"extends":[]}'
apply ALLOW_UNPINNED='["../x"]'
run "release-tags: rejects allow-unpinned with a hostile entry" fail "$script"
expect no-calls
finish
