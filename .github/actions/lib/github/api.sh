# shellcheck shell=bash
# Calls of the GitHub API through gh, which tell a missing resource from an
# error.

# Several helpers source this file; its read-only constant is defined once.
[[ ! -v NOT_FOUND ]] || return 0

# Status of api_request when the resource does not exist (HTTP 404).
readonly NOT_FOUND=3
# Attempts of a request that fails with a server error, a rate limit or no
# response, and the seconds to wait before the second one (doubled after).
readonly API_ATTEMPTS=3
readonly API_RETRY_DELAY=${API_RETRY_DELAY:-5}
readonly TRANSIENT_ERROR='HTTP (5[0-9][0-9]|429)|timeout|connection reset|unexpected EOF'

# is_transient ERROR_FILE: true when the error of gh in ERROR_FILE may pass
# on its own: a server error, a rate limit, or no HTTP status at all.
is_transient() {
  local error_file=$1
  grep -Eq "$TRANSIENT_ERROR" "$error_file" || ! grep -q 'HTTP [0-9]' "$error_file"
}

# should_retry STATUS ATTEMPT ERROR_FILE: true when a failed attempt may be
# repeated.
should_retry() {
  local status=$1 attempt=$2 error_file=$3
  ((status != 0 && attempt < API_ATTEMPTS)) || return 1
  is_transient "$error_file"
}

# report_response DIR STATUS: print the body in DIR after success; otherwise
# return NOT_FOUND for HTTP 404 or print the error and return 1.
report_response() {
  local dir=$1 status=$2
  if ((status == 0)); then
    cat -- "$dir/body"
  elif grep -q 'HTTP 404' "$dir/error"; then
    return "$NOT_FOUND"
  else
    cat -- "$dir/error" >&2
    return 1
  fi
}

# api_request METHOD PATH: print the response body. Returns 0 on success,
# NOT_FOUND when the resource does not exist and 1 on any other error, after
# printing the error. Transient errors are retried up to API_ATTEMPTS times.
api_request() {
  local method=$1 path=$2 tmp status attempt=1 delay=$API_RETRY_DELAY
  tmp=$(mktemp -d)
  while :; do
    status=0
    gh api -X "$method" "$path" >"$tmp/body" 2>"$tmp/error" || status=$?
    should_retry "$status" "$attempt" "$tmp/error" || break
    sleep "$delay"
    attempt=$((attempt + 1)) delay=$((delay * 2))
  done
  local result=0
  report_response "$tmp" "$status" || result=$?
  rm -rf -- "$tmp"
  return "$result"
}

# api_optional METHOD PATH: like api_request, but a missing resource is not an
# error and prints nothing.
api_optional() {
  local method=$1 path=$2 status=0
  api_request "$method" "$path" || status=$?
  ((status == 0 || status == NOT_FOUND)) || return 1
}

# api_get PATH: print a resource; fails when it does not exist.
api_get() {
  local path=$1 status=0
  api_request GET "$path" || status=$?
  if ((status == NOT_FOUND)); then echo "$path: Not Found (HTTP 404)" >&2; fi
  ((status == 0)) || return 1
}

# api_find PATH: print a resource; prints nothing when it does not exist.
api_find() { api_optional GET "$1"; }

# api_delete_if_exists PATH: delete a resource unless it is already gone.
api_delete_if_exists() { api_optional DELETE "$1" >/dev/null; }
