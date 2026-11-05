# shellcheck shell=bash
# Presets of a Renovate configuration.

# A preset of any source that names a repository: <platform>>owner/repo, then
# optionally //path, :name and #tag.
readonly REPOSITORY_PRESET='^[a-z]+>([^/:#]+/[^/:#]+)'
# A built-in preset of Renovate, such as config:recommended or
# :semanticCommits; it is versioned with Renovate itself.
readonly BUILTIN_PRESET='^(abandonments|config|customManagers|default|docker|group|helpers|mergeConfidence|monorepo|npm|packages|preview|regexManagers|replacements|schedule|security|workarounds)?:[^/]+$'
# The jq def preset_list: an extends as Renovate reads it, an array of
# presets that each fit on one line.
# shellcheck disable=SC2034 # Used by the scripts that source this file.
readonly PRESET_LIST_DEF='def preset_list:
  type == "array" and all(.[]; type == "string" and (test("[\\n\\r]") | not));'

# preset_source PRESET: print owner/repo of a preset of a repository on any
# platform, such as local>owner/repo; fails for any other preset.
preset_source() {
  local preset=$1
  [[ $preset =~ $REPOSITORY_PRESET ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
}

# is_github_preset PRESET: PRESET is a preset of a GitHub repository.
is_github_preset() {
  [[ $1 == github\>* ]]
}

# preset_repository PRESET: print owner/repo of a preset of a GitHub
# repository; fails for any other preset.
preset_repository() {
  local preset=$1
  is_github_preset "$preset" && preset_source "$preset"
}

# preset_tag PRESET: print the tag after the last "#" of a preset, or nothing.
preset_tag() {
  local preset=$1
  [[ $preset == *'#'* ]] || return 0
  printf '%s\n' "${preset##*#}"
}

# is_builtin_preset PRESET: PRESET is a built-in preset of Renovate.
is_builtin_preset() {
  [[ $1 =~ $BUILTIN_PRESET ]]
}
