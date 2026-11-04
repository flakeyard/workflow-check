# The verdict over the needs of the call, the needs of the job required and the
# jobs of the run attempt: one entry {name, result, ok} per job of the needs,
# and one per job of the attempt that fails the verdict.
# Arguments: $caller and $check, needs as JSON; $caller_may_skip, an array of
# job ids, which are also the names of those jobs in the attempt;
# $check_may_skip, an object of job ids and whether they may be skipped; $jobs,
# the jobs of the attempt; $own, the name of the job that runs the verdict,
# such as "check / required"; $prefix, what the caller job puts before the
# names of the jobs of this workflow, such as "check / ".

def may_skip_ids: to_entries | map(select(.value == true) | .key);

def listed($ids; $id): any($ids[]; . == $id);

# passed(MAY_SKIP; ID): the result of the job ID of the needs is a success.
def passed($may_skip; $id):
  .result == "success" or (.result == "skipped" and listed($may_skip; $id));

# needs_entries(SPACE; NEEDS; MAY_SKIP): the jobs of NEEDS, named SPACE.<id>.
def needs_entries($space; $needs; $may_skip):
  $needs | to_entries[] | .key as $id | .value
  | {name: "\($space).\($id)", result, ok: passed($may_skip; $id)};

# base_name: the name of a job of the attempt without the values of its
# matrix: "lint" of "lint (a, b)".
def base_name: sub(" \\(.*\\)$"; "");

def skipped: IN(.conclusion; "skipped", "neutral");

# may_skip_in_attempt: a job of the attempt that is matched by its name to an id
# of $caller_may_skip, since only the needs know the ids of jobs.
def may_skip_in_attempt: listed($caller_may_skip; .name | base_name);

def finished_well: .conclusion == "success" or (skipped and may_skip_in_attempt);

def completed_result:
  if skipped and (may_skip_in_attempt | not)
  then "\(.conclusion), not in caller-may-skip"
  else .conclusion end;

# of_this_workflow: a job of the attempt named after a job of this workflow:
# one of the needs of the verdict, or the job of the verdict itself. A caller
# job may have a name that starts with $prefix too.
def of_this_workflow:
  .name == $own
  or (.name | startswith($prefix) and (ltrimstr($prefix) | base_name | IN($check | keys[])));

# own_entry: the attempt lists the job of the verdict, or it is not the attempt
# of this run.
def own_entry:
  if any($jobs[]; .name == $own) then empty
  else {name: "run.\($own)", result: "missing from the jobs of the attempt", ok: false} end;

# attempt_entry: a job of the attempt outside this workflow. One that has not
# completed cannot be in the needs of the call; one that was skipped may be
# missing from them, so it fails unless it may be skipped.
def attempt_entry:
  if .status != "completed" then
    {name: "run.\(.name)", result: "\(.status), not in needs of the check job",
     ok: false}
  else
    {name: "run.\(.name)", result: completed_result, ok: finished_well}
  end;

[ needs_entries("caller"; $caller; $caller_may_skip),
  needs_entries("check"; $check; $check_may_skip | may_skip_ids),
  own_entry,
  ($jobs[] | select(of_this_workflow | not) | attempt_entry | select(.ok | not)) ]
