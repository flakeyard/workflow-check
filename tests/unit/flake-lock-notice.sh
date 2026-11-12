# shellcheck shell=bash
# Tests of flake-lock-notice.
# shellcheck disable=SC2016 # Code spans of the summary, not expansions.

step=flake-lock-notice

action_setup
apply ENABLED=false FLAKE=. NIXPKGS_EOL=true
run_step "flake-lock-notice: switched off" ok "$ACTIONS/$step" "$step"
expect message "::notice::the flake.lock check is off, and with it the end-of-life check of nixpkgs"
finish

action_setup
apply ENABLED=true FLAKE= NIXPKGS_EOL=true
run_step "flake-lock-notice: no flake" ok "$ACTIONS/$step" "$step"
expect message "::notice::no flake; no flake.lock to check"
finish

action_setup
apply ENABLED=true FLAKE=./dev NIXPKGS_EOL=true
run_step "flake-lock-notice: checked in the flake jobs" ok "$ACTIONS/$step" "$step"
expect notices 0
expect summary 'flake.lock of `./dev`: checked in the flake jobs'
finish

action_setup
apply ENABLED=true FLAKE=. NIXPKGS_EOL=false
run_step "flake-lock-notice: the end of life switched off" ok "$ACTIONS/$step" "$step"
expect message "::notice::the end-of-life check of nixpkgs is off"
expect summary 'flake.lock of `.`: checked in the flake jobs'
finish

# The notice of the whole check covers the end of life, once.
action_setup
apply ENABLED=false FLAKE=. NIXPKGS_EOL=false
run_step "flake-lock-notice: one notice when both are switched off" ok "$ACTIONS/$step" "$step"
expect no-message "::notice::the end-of-life check of nixpkgs is off"
finish

action_setup
apply ENABLED=true FLAKE=. NIXPKGS_EOL=false
run_hostile "flake-lock-notice: earlier steps of the job run no code in it" ok "$ACTIONS/$step" "$step"
expect message "::notice::the end-of-life check of nixpkgs is off"
finish
