# shellcheck shell=bash
# Tests of renovate-config.

script=renovate-config/run.sh
readonly FLAKEYARD_CONFIG='{"extends":["github>flakeyard/renovate-config//internal/workflow#v0.1.0"]}'

# renovate_setup CONFIG: renovate.json is CONFIG, and the presets of
# flakeyard/renovate-config are required.
renovate_setup() {
  setup
  apply ENABLED=true PRESETS='["flakeyard/renovate-config"]'
  file_fixture renovate.json "$1"
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

setup
apply ENABLED=true PRESETS='[]'
run "renovate-config: renovate.json is missing" fail "$script"
expect message "renovate.json is missing"
finish

for other in renovate.json5 .renovaterc .github/renovate.json .gitlab/renovate.json5; do
  renovate_setup "$FLAKEYARD_CONFIG"
  file_fixture "$other" '{}'
  run "renovate-config: $other is another configuration" fail "$script"
  expect message "remove $other: renovate.json must be the only Renovate configuration"
  finish
done

renovate_setup "$FLAKEYARD_CONFIG"
file_fixture package.json '{"name":"x","renovate":{"extends":[]}}'
run "renovate-config: package.json with a configuration" fail "$script"
expect message "remove the key renovate of package.json"
finish

# Every other configuration and no renovate.json: as many errors as a step
# writes, the last one included.
setup
apply ENABLED=true PRESETS='[]'
for other in renovate.json5 .renovaterc .renovaterc.json .renovaterc.json5 \
  .github/renovate.json .github/renovate.json5 .gitlab/renovate.json .gitlab/renovate.json5; do
  file_fixture "$other" '{}'
done
file_fixture package.json '{"renovate":{}}'
run "renovate-config: the tenth error is written" fail "$script"
expect message "renovate.json is missing"
finish

renovate_setup "$FLAKEYARD_CONFIG"
file_fixture package.json '{"name":"x"}'
run "renovate-config: package.json without a configuration" ok "$script"
finish

renovate_setup "$FLAKEYARD_CONFIG"
fixture "repos/$REPO/contents/.renovaterc?ref=$SHA" "HTTP 500"
run "renovate-config: an API error fails" fail "$script"
expect message "cannot read .renovaterc at $SHA"
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

setup
apply ENABLED=false PRESETS='[]'
run "renovate-config: switched off" ok "$script"
expect message "::notice::the renovate.json check is off"
finish
