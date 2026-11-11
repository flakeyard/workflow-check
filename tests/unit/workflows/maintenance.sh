# shellcheck shell=bash
# Static tests of the maintenance workflow of this repository: the weekly
# check of the end of life of the nixpkgs branch (FY-0026).
# shellcheck disable=SC2016 # jq expressions, not expansions.

: "${root:?}"

# maintenance_test NAME FILTER: FILTER is true of maintenance.yaml.
maintenance_test() { repository_check "$maintenance_workflow" "maintenance.yaml: $1" "$2"; }

if require_yq maintenance.yaml; then
  maintenance_workflow=$(load_workflow maintenance.yaml)
  maintenance_test "runs weekly and on dispatch only, never on pull requests" \
    '.on | keys == ["schedule", "workflow_dispatch"] and (.schedule | length == 1)
    and (.schedule[0].cron | test("^[0-9]+ [0-9]+ \\* \\* [0-6]$"))'
  maintenance_test "grants nothing at the top level" '.permissions == {}'
  maintenance_test "the job eol checks the EOL file with the flake as locked" \
    '[.jobs.eol.steps[] | .run // empty] == ["nix run --no-update-lock-file .#check-eol -- nixpkgs-eol"]'
  maintenance_test "actions are pinned by commit" \
    '[steps[] | .uses // empty | select(test($own_or_pinned) | not)] == []'
  maintenance_test "a dispatched run reports pending, then the result of eol" \
    '(.jobs.pending | condition == "github.event_name == '"'workflow_dispatch'"'")
    and (.jobs.result | .needs == ["pending", "eol"]
      and condition == "always() && github.event_name == '"'workflow_dispatch'"'")'
fi
