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

# next_page PATH PAGE BODY: answer page PAGE of a paginated GET PATH.
next_page() {
  local path=$1 page=$2 body=$3
  printf '%s\n' "$body" >"$(fixture_file "$path").$page"
}
