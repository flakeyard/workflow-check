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

# A preset of any source that names a repository: <platform>>owner/repo.
readonly REPOSITORY_PRESET='^[a-z]+>([^/:#]+/[^/:#]+)'
# A built-in preset of Renovate, such as config:recommended or
# :semanticCommits; it is versioned with Renovate itself.
readonly BUILTIN_PRESET='^(abandonments|config|customManagers|default|docker|group|helpers|mergeConfidence|monorepo|npm|packages|preview|regexManagers|replacements|schedule|security|workarounds)?:[^/]+$'

# preset_source PRESET: print owner/repo of a preset of a repository on any
# platform, such as local>owner/repo; fails for any other preset.
preset_source() {
  local preset=$1
  [[ $preset =~ $REPOSITORY_PRESET ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
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
