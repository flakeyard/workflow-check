# shellcheck shell=bash
# Presets of a Renovate configuration.

# A preset of a GitHub repository: github>owner/repo, then optionally //path,
# :name and #tag.
readonly GITHUB_PRESET='^github>([^/:#]+/[^/:#]+)'

# preset_repository PRESET: print owner/repo of a preset of a GitHub
# repository; fails for any other preset.
preset_repository() {
  local preset=$1
  [[ $preset =~ $GITHUB_PRESET ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
}
