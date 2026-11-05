# shellcheck shell=bash
# The form of the input flake, as the actions read it.

# The flake is in the checked-out repository: "." or a path below it.
# shellcheck disable=SC2034 # Used by the scripts that source this file.
readonly FLAKE_FORM='^\.(/[A-Za-z0-9_][A-Za-z0-9._-]*)*$'
