# shellcheck shell=bash
# Tests of lib/github/api.sh: a missing resource is told from an error.

lib=github/api.sh

# missing_is_not_found PATH: api_request returns NOT_FOUND for PATH.
missing_is_not_found() {
  local path=$1 status=0
  api_request GET "$path" || status=$?
  ((status == NOT_FOUND))
}

setup
fixture "repos/$REPO/thing" '{"a":1}'
run_lib "api: a resource is printed" ok "$lib" api_get "repos/$REPO/thing"
expect stdout '{"a":1}'
finish

setup
run_lib "api: a missing resource fails api_get" fail "$lib" api_get "repos/$REPO/thing"
expect message "repos/$REPO/thing: Not Found (HTTP 404)"
finish

setup
run_lib "api: a missing resource is NOT_FOUND" ok "$lib" missing_is_not_found "repos/$REPO/thing"
expect stdout ''
finish

setup
fixture "repos/$REPO/thing" "HTTP 500"
run_lib "api: a server error is an error" fail "$lib" api_request GET "repos/$REPO/thing"
expect message "HTTP 500"
finish

setup
fixture "repos/$REPO/thing" '{"a":1}'
transient_failures "repos/$REPO/thing" 2
run_lib "api: a gateway timeout is retried" ok "$lib" api_get "repos/$REPO/thing"
expect stdout '{"a":1}'
finish

setup
fixture "repos/$REPO/thing" '{"a":1}'
transient_failures "repos/$REPO/thing" 3
run_lib "api: a gateway timeout fails after the last attempt" fail "$lib" api_get "repos/$REPO/thing"
expect message "HTTP 504"
finish

setup
transient_failures "repos/$REPO/thing" 1
run_lib "api: a missing resource after a retry is NOT_FOUND" ok "$lib" missing_is_not_found "repos/$REPO/thing"
expect stdout ''
finish
