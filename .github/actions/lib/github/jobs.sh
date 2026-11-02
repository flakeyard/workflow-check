# shellcheck shell=bash source-path=SCRIPTDIR
# Jobs of workflow runs of REPO. Source this file; it expects REPO.

# shellcheck source=api.sh
source "${BASH_SOURCE[0]%/*}/api.sh"

# A check run id, which is also the id of its job.
readonly CHECK_RUN_ID_FORM='^[1-9][0-9]*$'

# job_name CHECK_RUN_ID: print the name of a job, such as "check / required".
job_name() {
  local id=$1 job
  [[ $id =~ $CHECK_RUN_ID_FORM ]] || {
    echo "not a check run id: $id" >&2
    return 1
  }
  job=$(api_get "repos/$REPO/actions/jobs/$id") || return 1
  jq -er '.name | strings' <<<"$job"
}

# caller_prefix NAME: print the part of a job name that its caller gives every
# job of a called workflow: "check / " of "check / required", or nothing for a
# job of the caller itself.
caller_prefix() {
  local name=$1
  if [[ $name == *' / '* ]]; then
    printf '%s / \n' "${name% / *}"
  fi
}

# Ids of workflow runs and numbers of their attempts.
readonly RUN_NUMBER_FORM='^[1-9][0-9]*$'

# attempt_jobs RUN_ID ATTEMPT: print the jobs of one attempt of a run, every
# job of the run with the result it has in that attempt, as a JSON array of
# {name, status, conclusion}.
attempt_jobs() {
  local run_id=$1 attempt=$2 jobs
  [[ $run_id =~ $RUN_NUMBER_FORM && $attempt =~ $RUN_NUMBER_FORM ]] || {
    echo "not a run id and attempt: $run_id, $attempt" >&2
    return 1
  }
  jobs=$(gh api --paginate \
    "repos/$REPO/actions/runs/$run_id/attempts/$attempt/jobs?per_page=100" \
    --jq '.jobs[] | {name, status, conclusion}') || return 1
  jq -s . <<<"$jobs"
}
