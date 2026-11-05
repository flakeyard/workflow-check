# shellcheck shell=bash
# Tests of flake-lock-notice.
# shellcheck disable=SC2016 # Code spans of the summary, not expansions.

script="flake-lock-notice/run.sh"

setup
apply ENABLED=false FLAKE=.
run "flake-lock-notice: switched off" ok "$script"
expect message "::notice::the flake.lock check is off"
finish

setup
apply ENABLED=true FLAKE=
run "flake-lock-notice: no flake" ok "$script"
expect message "::notice::no flake; no flake.lock to check"
finish

setup
apply ENABLED=true FLAKE=./dev
run "flake-lock-notice: checked in the flake jobs" ok "$script"
expect no-command notice
expect summary 'flake.lock of `./dev`: checked in the flake jobs'
finish
