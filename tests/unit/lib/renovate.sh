# shellcheck shell=bash
# Tests of lib/renovate.sh.

lib=renovate.sh

for preset in "github>flakeyard/renovate-config" "github>flakeyard/renovate-config#v0.1.0" \
  "github>flakeyard/renovate-config//internal/workflow#v0.1.0" "github>flakeyard/renovate-config:x"; do
  setup
  run_lib "renovate: the repository of $preset" ok "$lib" preset_repository "$preset"
  expect stdout "flakeyard/renovate-config"
  finish
done

for preset in ":semanticCommits" "local>flakeyard/renovate-config" "gitlab>a/b" \
  "https://example.org/preset.json" "github>flakeyard"; do
  setup
  run_lib "renovate: no GitHub repository in $preset" fail "$lib" preset_repository "$preset"
  finish
done
