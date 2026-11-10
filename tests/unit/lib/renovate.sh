# shellcheck shell=bash
# Tests of lib/renovate.sh.

lib=.github/actions/lib/renovate.sh

for preset in "github>flakeyard/renovate-config" "github>flakeyard/renovate-config#v0.1.0" \
  "github>flakeyard/renovate-config//internal/workflow#v0.1.0" "github>flakeyard/renovate-config:x"; do
  action_setup
  run_lib "renovate: the repository of $preset" ok "$lib" preset_repository "$preset"
  expect stdout "flakeyard/renovate-config"
  finish
done

for preset in ":semanticCommits" "local>flakeyard/renovate-config" "gitlab>a/b" \
  "https://example.org/preset.json" "github>flakeyard"; do
  action_setup
  run_lib "renovate: no GitHub repository in $preset" fail "$lib" preset_repository "$preset"
  finish
done

action_setup
run_lib "renovate: the tag of a preset" ok "$lib" preset_tag "github>a/b//p:c#v1.2.3"
expect stdout "v1.2.3"
finish

action_setup
run_lib "renovate: no tag" ok "$lib" preset_tag "github>a/b"
expect stdout ""
finish

action_setup
run_lib "renovate: the repository of a local preset" ok "$lib" preset_source "local>a/b:c"
expect stdout "a/b"
finish

for preset in ":semanticCommits" "config:recommended" "helpers:pinGitHubActionDigests"; do
  action_setup
  run_lib "renovate: $preset is built in" ok "$lib" is_builtin_preset "$preset"
  finish
done

for preset in "acme:x" "github>a/b" "@acme/renovate-config" "renovate-config-acme"; do
  action_setup
  run_lib "renovate: $preset is not built in" fail "$lib" is_builtin_preset "$preset"
  finish
done
