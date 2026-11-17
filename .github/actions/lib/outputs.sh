# shellcheck shell=bash
# The per-system outputs of the flake, such as checks and apps, as
# flake-checks and flake-apps read them: the form of a system and of an output
# name, the nix of the job and the names of an output. Source this file after
# env.sh, with step_environment run, and report.sh.

readonly SYSTEM_FORM='^[a-z0-9_]+-[a-z0-9_]+$'
# An attribute name that needs no escape between double quotes and cannot be
# read as an option. jq, whose $ also matches before a final newline, so \A
# and \z.
readonly OUTPUT_NAME_FORM='\A[A-Za-z0-9_][A-Za-z0-9_.+-]*\z'

# check_system SYSTEM: fails unless SYSTEM has the form of a system.
check_system() {
  [[ $1 =~ ${SYSTEM_FORM} ]] || fail "not a system: $1"
}

# is_name_list JSON: JSON is an array of output names, empty or not.
is_name_list() {
  jq -e --arg form "${OUTPUT_NAME_FORM}" 'type == "array" and all(.[]; type == "string" and test($form))' \
    <<<"$1" >/dev/null 2>&1
}

# find_nix: set nix to the nix of the PATH of the job, where action-setup-nix
# puts it; every other tool comes from SYSTEM_PATH.
find_nix() {
  nix=$(job_tool nix) \
    || fail "no nix on the PATH of the job: install Nix before this step, such as with flakeyard/action-setup-nix"
}

# read_names ARRAY JSON: set the array named ARRAY to the names of JSON, an
# array of output names.
# shellcheck disable=SC2034 # read_names_into is the caller's ARRAY.
read_names() {
  local -n read_names_into=$1
  local listed
  listed=$(jq -r '.[]' <<<"$2")
  read_names_into=()
  # A name matches OUTPUT_NAME_FORM, so an empty line is no name.
  [[ -z ${listed} ]] || mapfile -t read_names_into <<<"${listed}"
}

# output_names FLAKE SYSTEM OUTPUT EXPECTED [OPTION...]: set names to the
# names of OUTPUT.SYSTEM of FLAKE, read with nix and OPTION...; fails when
# they cannot be read, when a name of EXPECTED, a JSON array, is missing, in
# the order of EXPECTED, or when a name has not the form of an output name.
output_names() {
  local flake=$1 system=$2 output=$3 expected=$4 found missing
  shift 4
  found=$("${nix}" eval "$@" --json "${flake}#." \
    --apply "outputs: builtins.attrNames ((outputs.${output} or { }).\"${system}\" or { })") \
    || fail "cannot evaluate the ${output} of the flake ${flake}"
  missing=$(jq -r --argjson found "${found}" '. - $found | join(", ")' <<<"${expected}")
  [[ -z ${missing} ]] || fail "the flake ${flake} has no ${output}.${system} of: ${missing}"
  # shellcheck disable=SC2310 # is_name_list is one test; its status is the result.
  is_name_list "${found}" || fail "the names of ${output}.${system} must match ${OUTPUT_NAME_FORM}"
  read_names names "${found}"
}
