---
id: ADR-0007
title: Check merge groups of the merge queue
status: accepted
date: 2026-11-22
supersedes: []
superseded_by: []
related: [ADR-0001]
affects:
  [
    ".github/workflows/check.yaml",
    ".github/actions/preflight/**",
    ".github/actions/pr-title/**",
  ]
review_by:
---

## Context

[FY-0041][fy-0041] merges pull requests to the default branch only through the
merge queue. The queue puts each pull request on top of the tip of the branch,
pushes that commit to a branch `gh-readonly-queue/<base>/pr-<N>-<sha>` and
starts the check workflow of the repository with the event `merge_group`. The
check run `check / required` of that run satisfies the required check of the
ruleset, as the probe of FY-0041 showed, and every repository with CI triggers
its `test.yaml` on `merge_group`.

[ADR-0001][adr-0001] lists the events `pull_request`, `push`, `schedule` and
`workflow_dispatch`, and requires `check.yaml` to fail on any other. A
`merge_group` run therefore fails in the job `preflight`, and the queue removes
every pull request. Step 1 of the rollout of FY-0041 is a release of
workflow-check that accepts the event.

What shapes the design:

- A `merge_group` run has no `pull_request` in its payload. It has
  `merge_group.head_ref`, the full ref of the queue branch, which names the
  number of the queued pull request, and `merge_group.head_sha`, which is
  `github.sha`.
- The queue squashes with the title of the pull request at merge time, and an
  edit of the title keeps the pull request in the queue (FY-0041). The title
  checked by the `pull_request` run is therefore not always the title that
  reaches the default branch.
- `max_entries_to_merge` is 1 (FY-0041): every group merges one pull request,
  the one its queue branch names. A group built on another one also holds the
  changes of the pull requests ahead of it, whose titles their own groups check.
- The steps that read repository files use `github.sha`, and the job that builds
  the flake checks out `github.sha`: in a `merge_group` run both are the commit
  of the group, the tree that reaches the branch.
- Only `workflow_dispatch` runs post commit statuses, and the job `pending` runs
  only for them.

## Decision

`check.yaml` accepts `merge_group` as a fifth event. A `merge_group` run checks
as a `pull_request` run does, at the commit of the group, and like every run
other than `workflow_dispatch` it posts no commit status.

### Title of the queued pull request

On `merge_group`, `pr-title` takes the number of the queued pull request from
`github.event.merge_group.head_ref`, which has the form
`refs/heads/gh-readonly-queue/<base>/pr-<N>-<sha>`, reads the title of that pull
request from the API and checks it with the rule of `pull_request` runs. A head
ref of another form fails the step with a message that names it, so a change of
the queue's branch names is noticed instead of passing without a check. The
title is read with `pull-requests: read`, which the workflow already has.

### Caller

The check workflow of a caller triggers on `merge_group` and does not cancel a
`merge_group` run in progress, as FY-0041 requires. The concurrency rule of the
caller example in the README, which cancels only `pull_request` runs other than
`edited`, already keeps such runs.

### Changes to ADR-0001

This record amends ADR-0001; its other decisions and constraints stand. Its
"Public API" lists also the event `merge_group`, and the constraint that
`check.yaml` accepts only the events listed holds for that list. On
`merge_group`, the check of the pull request title checks the title of the
queued pull request. The caller contract gains the rule of FY-0041 above.

## Constraints

- `check.yaml` MUST accept `merge_group` in addition to the events of ADR-0001,
  and MUST still fail on any other event.
- A caller's check workflow MUST trigger on `merge_group` and MUST NOT cancel a
  `merge_group` run in progress ([FY-0041][fy-0041]).
- On `merge_group`, `pr-title` MUST check the title, read from the API, of the
  pull request named by `github.event.merge_group.head_ref`, and MUST fail when
  that ref does not have the form
  `refs/heads/gh-readonly-queue/<base>/pr-<N>-<sha>`.
- The check of a `merge_group` run MUST NOT need a permission beyond those of
  ADR-0001.

## Consequences

- (+) Repositories can merge through the queue with workflow-check as their
  required check.
- (+) A title edited while the pull request waits in the queue is checked before
  the squash commit takes it.
- (−) The check depends on the form of the queue's branch names; a change by
  GitHub fails the title check of every `merge_group` run until workflow-check
  follows it.
- (−) A title edited after the `merge_group` run passed still reaches the branch
  unchecked.
- (±) A `merge_group` run repeats the whole check of the pull request, flake
  builds included (FY-0041).

## Alternatives considered

- **No title check on `merge_group`, as on `push`.** Simpler, but a title edited
  in the queue would reach the default branch unchecked.
- **Find the pull request through the API.** The payload names no pull request
  and the commit of the group is the head of none; listing the open pull
  requests and matching them costs calls and adds no certainty over the number
  in the queue branch.

[adr-0001]: 0001-check-pull-requests-and-pushes.md
[fy-0041]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0041-merge-through-the-merge-queue.md
