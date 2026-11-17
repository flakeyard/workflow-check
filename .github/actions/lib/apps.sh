# shellcheck shell=bash
# The form of the input apps, as the actions read it. Source this file after
# report.sh and outputs.sh.

# check_apps APPS: fails unless APPS is a JSON array of app names; an empty
# value is none.
check_apps() {
  # shellcheck disable=SC2310 # is_name_list is one test; its status is the result.
  is_name_list "$1" || fail "apps is not a JSON array of app names, such as [] or [\"markdown-links\"]"
}
