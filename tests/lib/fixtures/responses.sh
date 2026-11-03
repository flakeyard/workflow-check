# shellcheck shell=bash
# Responses of the gh stub, read from the files of FIXTURES.

# fixture_file PATH: the file that answers GET PATH, as the gh stub names it.
fixture_file() {
  local path=$1
  printf '%s\n' "$FIXTURES/${path//[\/?&=]/_}"
}

# fixture PATH BODY: answer GET PATH with BODY.
fixture() {
  local path=$1 body=$2
  printf '%s\n' "$body" >"$(fixture_file "$path")"
}

# transient_failures PATH COUNT: fail the next COUNT GETs of PATH with HTTP 504.
transient_failures() {
  local path=$1 count=$2
  printf '%s\n' "$count" >"$(fixture_file "$path").transient"
}

# next_page PATH PAGE BODY: answer page PAGE of a paginated GET PATH.
next_page() {
  local path=$1 page=$2 body=$3
  printf '%s\n' "$body" >"$(fixture_file "$path").$page"
}

# file_fixture PATH CONTENT: answer the contents API for a file at SHA, with
# the base64 wrapped at 60 characters like the API does.
file_fixture() {
  local path=$1 content=$2 encoded
  encoded=$(printf '%s' "$content" | base64 -w 60 | paste -sd '#' | sed 's/#/\\n/g')
  fixture "repos/$REPO/contents/$path?ref=$SHA" \
    "{\"type\":\"file\",\"encoding\":\"base64\",\"content\":\"$encoded\"}"
}
