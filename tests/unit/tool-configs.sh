# shellcheck shell=bash
# Tests of tool-configs.

step=tool-configs
# The inline-comment alternative that every error names.
readonly ALTERNATIVE="write each exception as an inline comment of the tool instead"

# tool_setup: the check is on, and the root and .github have no configuration
# files of atom tools.
tool_setup() {
  action_setup
  apply ENABLED=true
  listing_fixture "" README.md .github/
  listing_fixture .github workflows/ actions/
}

tool_setup
run_step "tool-configs: no configuration files" ok "$ACTIONS/$step" "$step"
expect summary "no configuration files of atom tools"
finish

for path in .github/actionlint.yaml .github/actionlint.yml .github/zizmor.yml .github/zizmor.yaml \
  zizmor.yml zizmor.yaml; do
  tool_setup
  if [[ $path == */* ]]; then
    listing_fixture .github workflows/ "${path#*/}"
  else
    listing_fixture "" README.md .github/ "$path"
  fi
  run_step "tool-configs: $path fails" fail "$ACTIONS/$step" "$step"
  expect message "::error file=$path::remove $path: the atom's default configuration of the tool applies; $ALTERNATIVE, such as # zizmor: ignore[<audit>]"
  finish
done

# An entry of any type: a directory or a symbolic link is a configuration too.
tool_setup
listing_fixture "" README.md .github/ zizmor.yml/
fixture "repos/$REPO/contents/.github?ref=$SHA" \
  '[{"name":"actionlint.yaml","type":"symlink"},{"name":"workflows","type":"dir"}]'
run_step "tool-configs: entries of any type fail, each named" fail "$ACTIONS/$step" "$step"
expect errors 2
expect message "remove zizmor.yml:"
expect message "remove .github/actionlint.yaml:"
finish

# Names that are only like the paths, in other directories or of other case.
tool_setup
listing_fixture "" README.md .github/ actionlint.yaml Zizmor.yml zizmor.yml.bak
listing_fixture .github workflows/ zizmor.json ZIZMOR.YML
run_step "tool-configs: only the exact paths fail" ok "$ACTIONS/$step" "$step"
finish

action_setup
apply ENABLED=true
listing_fixture "" README.md
run_step "tool-configs: no .github" ok "$ACTIONS/$step" "$step"
finish

# The requests are an independent oracle: one listing of each directory of
# the paths, the root and .github.
tool_setup
apply LOG_GETS=1
run_step "tool-configs: one listing of each directory" ok "$ACTIONS/$step" "$step"
expect_calls 2
expect call "GET repos/$REPO/contents?ref=$SHA"
expect call "GET repos/$REPO/contents/.github?ref=$SHA"
finish

tool_setup
fixture "repos/$REPO/contents/.github?ref=$SHA" "HTTP 500"
run_step "tool-configs: an error of the API fails" fail "$ACTIONS/$step" "$step"
expect message "cannot list .github at $SHA"
finish

for enabled in false ""; do
  action_setup
  apply ENABLED="$enabled"
  run_step "tool-configs: off with '$enabled'" "$([[ -n $enabled ]] && echo ok || echo fail)" "$ACTIONS/$step" "$step"
  [[ -z $enabled ]] || expect message "::notice::the check of configuration files of atom tools is off"
  [[ -z $enabled ]] || expect_calls 0
  finish
done

tool_setup
listing_fixture "" README.md .github/ zizmor.yaml
run_hostile "tool-configs: earlier steps of the job run no code in it" fail "$ACTIONS/$step" "$step"
expect message "remove zizmor.yaml:"
finish
