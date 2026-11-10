# shellcheck shell=bash
# Tests of lib/github/jobs.sh.

lib=.github/actions/lib/github/jobs.sh

action_setup
run_lib "jobs: the caller prefix of a called job" ok "$lib" caller_prefix "check / meta"
expect stdout "check / "
finish

action_setup
run_lib "jobs: no caller prefix of a job of the caller" ok "$lib" caller_prefix "install (x86_64-linux)"
expect stdout ""
finish
