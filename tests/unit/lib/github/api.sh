# shellcheck shell=bash
# Tests of lib/github/api.sh: a missing resource is told from an error.

lib=github/api.sh

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
run_lib "api: a missing resource is nothing to api_find" ok "$lib" api_find "repos/$REPO/thing"
expect stdout ''
finish

setup
fixture "repos/$REPO/thing" "HTTP 500"
run_lib "api: a server error fails api_find" fail "$lib" api_find "repos/$REPO/thing"
finish

setup
fixture "repos/$REPO/thing" '{"a":1}'
echo 2 >"$FIXTURES/repos_${REPO//\//_}_thing.transient"
run_lib "api: a gateway timeout is retried" ok "$lib" api_get "repos/$REPO/thing"
expect stdout '{"a":1}'
finish

setup
fixture "repos/$REPO/thing" '{"a":1}'
echo 3 >"$FIXTURES/repos_${REPO//\//_}_thing.transient"
run_lib "api: a gateway timeout fails after the last attempt" fail "$lib" api_get "repos/$REPO/thing"
expect message "HTTP 504"
finish

setup
echo 1 >"$FIXTURES/repos_${REPO//\//_}_thing.transient"
run_lib "api: a missing resource after a retry is nothing to api_find" ok "$lib" api_find "repos/$REPO/thing"
expect stdout ''
finish
