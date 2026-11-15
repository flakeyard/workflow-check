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
: "${SHELL_LIB:?}" "${REPO:?}" "${RUN_ID:?}" "${RUN_ATTEMPT:?}" "${CHECK_RUN_ID?}"
: "${CALLER?}" "${CHECK:?}" "${CALLER_MAY_SKIP:?}" "${CHECK_MAY_SKIP:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "${SHELL_LIB}/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0004).
lib=${0%/*}/../../../lib
# shellcheck source=../../../lib/github/jobs.sh
source "${lib}/github/jobs.sh"
# shellcheck source=/dev/null
source "${SHELL_LIB}/report.sh"

# shellcheck disable=SC2016 # The expression is the text the caller writes.
readonly NEEDS_HINT='pass needs: ${{ toJSON(needs) }} in the call'

# jq filters, true for a needs context, an object of jobs with a result; for
# an array of job ids; and for an object of job ids and booleans.
readonly NEEDS='type == "object" and all(.[]; type == "object" and (.result | type) == "string")'
readonly ID_LIST='type == "array" and all(.[]; type == "string")'
readonly SKIP_MAP='type == "object" and all(.[]; type == "boolean")'

check_inputs() {
  jq -e "${NEEDS}" <<<"${CALLER}" >/dev/null 2>&1 \
    || fail "the input needs is missing or malformed; ${NEEDS_HINT}"
  jq -e "${NEEDS}" <<<"${CHECK}" >/dev/null 2>&1 || fail "the needs of the job required are malformed"
  jq -e "${ID_LIST}" <<<"${CALLER_MAY_SKIP}" >/dev/null 2>&1 \
    || fail "caller-may-skip is not a JSON array of job ids"
  jq -e "${SKIP_MAP}" <<<"${CHECK_MAY_SKIP}" >/dev/null 2>&1 \
    || fail "check-may-skip is not a JSON object of booleans"
  # CHECK_MAY_SKIP names only jobs of CHECK.
  jq -e --argjson needs "${CHECK}" 'keys - ($needs | keys) == []' <<<"${CHECK_MAY_SKIP}" >/dev/null \
    || fail "check-may-skip names jobs that are not in the needs of the job required"
}

# verdict OWN PREFIX JOBS: print the entries of verdict.jq.
verdict() {
  local own=$1 prefix=$2 jobs=$3
  jq -n --argjson caller "${CALLER}" --argjson check "${CHECK}" \
    --argjson caller_may_skip "${CALLER_MAY_SKIP}" \
    --argjson check_may_skip "${CHECK_MAY_SKIP}" \
    --argjson jobs "${jobs}" --arg own "${own}" --arg prefix "${prefix}" \
    -f "${0%/*}/../../verdict.jq"
}

# summary_table ENTRIES: write the entries to the job summary.
summary_table() {
  local entries=$1 rows name result
  summary "| Job | Result |"
  summary "| --- | --- |"
  rows=$(jq -r '.[] | [.name, .result] | @tsv' <<<"${entries}")
  while IFS=$'\t' read -r name result; do
    [[ -n ${name} ]] || continue
    name=$(code_span "${name}")
    result=$(code_span "${result}")
    summary "| ${name} | ${result} |"
  done <<<"${rows}"
}

check_inputs
# shellcheck disable=SC2310 # job_name returns 1 on every failure itself.
own=$(job_name "${CHECK_RUN_ID}") || fail "cannot read the name of job ${CHECK_RUN_ID}"
prefix=$(caller_prefix "${own}")
[[ -n ${prefix} ]] || fail "job ${own} does not run in a called workflow"
# shellcheck disable=SC2310 # attempt_jobs returns 1 on every failure itself.
jobs=$(attempt_jobs "${RUN_ID}" "${RUN_ATTEMPT}") \
  || fail "cannot read the jobs of attempt ${RUN_ATTEMPT} of run ${RUN_ID}"
entries=$(verdict "${own}" "${prefix}" "${jobs}")
summary_table "${entries}"
failures=$(jq -r '[.[] | select(.ok | not) | "\(.name): \(.result)"] | join(", ")' <<<"${entries}")
[[ -z ${failures} ]] || fail "jobs that did not succeed: ${failures}"
