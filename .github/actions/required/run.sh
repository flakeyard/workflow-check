#!/usr/bin/env bash
# Fails unless every job in CALLER and CHECK, the needs of the caller job and
# of this job, succeeded or is allowed to be skipped by CALLER_MAY_SKIP and
# CHECK_MAY_SKIP, and every job of attempt RUN_ATTEMPT of run RUN_ID outside
# this workflow has completed and succeeded, or was skipped and may be. A job
# that has not completed is missing from the needs of the caller job. Fails
# also when the attempt does not list this job. Writes a table of the jobs to
# the job summary.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
# Ranges such as [a-z] match only ASCII, whatever the locale of the runner.
export LC_ALL=C.UTF-8
: "${SHELL_LIB:?}" "${REPO:?}" "${RUN_ID:?}" "${RUN_ATTEMPT:?}" "${CHECK_RUN_ID?}"
: "${CALLER?}" "${CHECK:?}" "${CALLER_MAY_SKIP:?}" "${CHECK_MAY_SKIP:?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/github/jobs.sh
source "$lib/github/jobs.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"

# shellcheck disable=SC2016 # The expression is the text the caller writes.
readonly NEEDS_HINT='pass needs: ${{ toJSON(needs) }} in the call'

# is_needs JSON: JSON is a needs context, an object of jobs with a result.
is_needs() {
  jq -e 'type == "object" and all(.[]; type == "object" and (.result | type) == "string")' \
    <<<"$1" >/dev/null 2>&1
}

# is_id_list JSON: JSON is an array of job ids.
is_id_list() {
  jq -e 'type == "array" and all(.[]; type == "string")' <<<"$1" >/dev/null 2>&1
}

# is_skip_map JSON: JSON is an object of job ids and booleans.
is_skip_map() {
  jq -e 'type == "object" and all(.[]; type == "boolean")' <<<"$1" >/dev/null 2>&1
}

check_inputs() {
  is_needs "$CALLER" || fail "the input needs is missing or malformed; $NEEDS_HINT"
  is_needs "$CHECK" || fail "the needs of the job required are malformed"
  is_id_list "$CALLER_MAY_SKIP" || fail "caller-may-skip is not a JSON array of job ids"
  is_skip_map "$CHECK_MAY_SKIP" || fail "check-may-skip is not a JSON object of booleans"
  is_skip_map_of "$CHECK" || fail "check-may-skip names jobs that are not in the needs of the job required"
}

# is_skip_map_of NEEDS: CHECK_MAY_SKIP names only jobs of NEEDS.
is_skip_map_of() {
  jq -e --argjson needs "$1" 'keys - ($needs | keys) == []' <<<"$CHECK_MAY_SKIP" >/dev/null
}

# verdict OWN PREFIX JOBS: print the entries of verdict.jq.
verdict() {
  local own=$1 prefix=$2 jobs=$3
  jq -n --argjson caller "$CALLER" --argjson check "$CHECK" \
    --argjson caller_may_skip "$CALLER_MAY_SKIP" \
    --argjson check_may_skip "$CHECK_MAY_SKIP" \
    --argjson jobs "$jobs" --arg own "$own" --arg prefix "$prefix" \
    -f "$(dirname "$0")/verdict.jq"
}

# summary_table ENTRIES: write the entries to the job summary.
summary_table() {
  local entries=$1 name result
  summary "| Job | Result |"
  summary "| --- | --- |"
  while IFS=$'\t' read -r name result; do
    summary "| $(code_span "$name") | $(code_span "$result") |"
  done < <(jq -r '.[] | [.name, .result] | @tsv' <<<"$entries")
}

check_inputs
own=$(job_name "$CHECK_RUN_ID") || fail "cannot read the name of job $CHECK_RUN_ID"
prefix=$(caller_prefix "$own")
[[ -n $prefix ]] || fail "job $own does not run in a called workflow"
jobs=$(attempt_jobs "$RUN_ID" "$RUN_ATTEMPT") \
  || fail "cannot read the jobs of attempt $RUN_ATTEMPT of run $RUN_ID"
entries=$(verdict "$own" "$prefix" "$jobs")
summary_table "$entries"
failures=$(jq -r '[.[] | select(.ok | not) | "\(.name): \(.result)"] | join(", ")' <<<"$entries")
[[ -z $failures ]] || fail "jobs that did not succeed: $failures"
