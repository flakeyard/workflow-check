# shellcheck shell=bash
# Tests of flake-lock-notice.
# shellcheck disable=SC2016 # Code spans of the summary, not expansions.

script="flake-lock-notice/run.sh"

setup
apply ENABLED=false FLAKE=. NIXPKGS_EOL=true
run "flake-lock-notice: switched off" ok "$script"
expect message "::notice::the flake.lock check is off, and with it the end-of-life check of nixpkgs"
finish

setup
apply ENABLED=true FLAKE= NIXPKGS_EOL=true
run "flake-lock-notice: no flake" ok "$script"
expect message "::notice::no flake; no flake.lock to check"
finish

setup
apply ENABLED=true FLAKE=./dev NIXPKGS_EOL=true
run "flake-lock-notice: checked in the flake jobs" ok "$script"
expect no-command notice
expect summary 'flake.lock of `./dev`: checked in the flake jobs'
finish

setup
apply ENABLED=true FLAKE=. NIXPKGS_EOL=false
run "flake-lock-notice: the end of life switched off" ok "$script"
expect message "::notice::the end-of-life check of nixpkgs is off"
expect summary 'flake.lock of `.`: checked in the flake jobs'
finish

# The notice of the whole check covers the end of life, once.
setup
apply ENABLED=false FLAKE=. NIXPKGS_EOL=false
run "flake-lock-notice: one notice when both are switched off" ok "$script"
expect no-message "::notice::the end-of-life check of nixpkgs is off"
finish
