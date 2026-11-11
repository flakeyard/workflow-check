# shellcheck shell=bash
# Tests of renovate-config.

script=.github/actions/renovate-config/run.sh
readonly FLAKEYARD_CONFIG='{"extends":["github>flakeyard/renovate-config//internal/workflow#v0.1.0"]}'

# renovate_setup CONFIG: renovate.json is CONFIG and the only file at the
# root, and the presets of flakeyard/renovate-config are required.
renovate_setup() {
  action_setup
  apply ENABLED=true PRESETS='["flakeyard/renovate-config"]'
  file_fixture "$REPO" renovate.json "$SHA" "$1"
  listing_fixture "" renovate.json
}

# other_setup PATH: renovate.json and PATH, at the root or in a directory of
# it, are the only files.
other_setup() {
  local path=$1
  if [[ $path == */* ]]; then
    listing_fixture "" renovate.json "${path%%/*}/"
    listing_fixture "${path%%/*}" "${path#*/}"
  else
    listing_fixture "" renovate.json "$path"
  fi
}

renovate_setup "$FLAKEYARD_CONFIG"
run "renovate-config: extends a listed preset" ok "$script"
finish

renovate_setup '{"extends":[":semanticCommits","github>FlakeYard/Renovate-Config#v0.1.0"]}'
run "renovate-config: repositories are compared without case" ok "$script"
finish

renovate_setup '{"extends":["github>someone/presets"]}'
apply PRESETS='[]'
run "renovate-config: any preset without a list" ok "$script"
finish

renovate_setup '{"extends":["github>someone/presets#v1.0.0","local>flakeyard/renovate-config"]}'
run "renovate-config: no listed preset" fail "$script"
expect message "renovate.json must extend a preset of one of: flakeyard/renovate-config"
finish

renovate_setup '{"extends":["github>flakeyard/renovate-config-fork"]}'
run "renovate-config: a repository whose name only starts like a listed one" fail "$script"
finish

for config in '{}' '{"extends":[]}' '{"extends":"github>flakeyard/renovate-config"}' \
  '{"extends":[1]}' '{"extends":["github>x/y\ngithub>flakeyard/renovate-config"]}'; do
  renovate_setup "$config"
  run "renovate-config: rejects the extends of $config" fail "$script"
  expect message "renovate.json must extend presets"
  finish
done

for config in '[]' 'not json' ''; do
  renovate_setup "$config"
  run "renovate-config: rejects '$config'" fail "$script"
  expect message "renovate.json is not a JSON object"
  finish
done

action_setup
apply ENABLED=true PRESETS='[]'
listing_fixture ""
run "renovate-config: renovate.json is missing" fail "$script"
expect message "renovate.json is missing"
finish

for other in renovate.json5 .renovaterc .github/renovate.json .gitlab/renovate.json5; do
  renovate_setup "$FLAKEYARD_CONFIG"
  other_setup "$other"
  run "renovate-config: $other is another configuration" fail "$script"
  expect message "remove $other: renovate.json must be the only Renovate configuration"
  finish
done

renovate_setup "$FLAKEYARD_CONFIG"
other_setup package.json
file_fixture "$REPO" package.json "$SHA" '{"name":"x","renovate":{"extends":[]}}'
run "renovate-config: package.json with a configuration" fail "$script"
expect message "remove the key renovate of package.json"
finish

# Every other configuration and no renovate.json: as many errors as a step
# writes, the last one included.
action_setup
apply ENABLED=true PRESETS='[]'
listing_fixture "" renovate.json5 .renovaterc .renovaterc.json .renovaterc.json5 \
  .github/ .gitlab/ package.json
listing_fixture .github renovate.json renovate.json5
listing_fixture .gitlab renovate.json renovate.json5
file_fixture "$REPO" package.json "$SHA" '{"renovate":{}}'
run "renovate-config: the tenth error is written" fail "$script"
expect message "renovate.json is missing"
finish

renovate_setup "$FLAKEYARD_CONFIG"
other_setup package.json
file_fixture "$REPO" package.json "$SHA" '{"name":"x"}'
run "renovate-config: package.json without a configuration" ok "$script"
finish

# The requests are an independent oracle: one listing of the root, one of
# each directory of other configurations that exists, and renovate.json.
renovate_setup "$FLAKEYARD_CONFIG"
apply LOG_GETS=1
run "renovate-config: one listing of the root" ok "$script"
expect_calls 2
expect call "GET repos/$REPO/contents?ref=$SHA"
finish

renovate_setup "$FLAKEYARD_CONFIG"
listing_fixture "" renovate.json .github/ src/
listing_fixture .github workflows/
apply LOG_GETS=1
run "renovate-config: a listing of .github, only because it exists" ok "$script"
expect_calls 3
expect call "GET repos/$REPO/contents/.github?ref=$SHA"
expect no-call "/.gitlab?"
finish

renovate_setup "$FLAKEYARD_CONFIG"
fixture "repos/$REPO/contents?ref=$SHA" "HTTP 500"
run "renovate-config: an API error fails" fail "$script"
expect message "cannot list the root at $SHA"
finish

renovate_setup "$FLAKEYARD_CONFIG"
listing_fixture "" renovate.json .gitlab/
fixture "repos/$REPO/contents/.gitlab?ref=$SHA" "HTTP 500"
run "renovate-config: an API error of a directory fails" fail "$script"
expect message "cannot list .gitlab at $SHA"
finish

renovate_setup "$FLAKEYARD_CONFIG"
fixture "repos/$REPO/contents/renovate.json?ref=$SHA" '[{"type":"file","name":"x"}]'
run "renovate-config: a directory is not a configuration" fail "$script"
finish

for presets in '"flakeyard/renovate-config"' '["../x"]' '["flakeyard/.."]' '["flakeyard"]' ''; do
  renovate_setup "$FLAKEYARD_CONFIG"
  apply PRESETS="$presets"
  run "renovate-config: rejects the presets $presets" fail "$script"
  expect message "renovate-presets is not a JSON array of owner/repo"
  expect no-calls
  finish
done

action_setup
apply ENABLED=false PRESETS='[]'
run "renovate-config: switched off" ok "$script"
expect message "::notice::the renovate.json check is off"
finish
